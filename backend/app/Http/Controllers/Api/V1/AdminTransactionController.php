<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Concerns\AdminHelpers;
use App\Http\Controllers\Controller;
use App\Models\AdminActionLog;
use App\Models\Conversation;
use App\Models\Transaction;
use App\Models\UserReport;
use App\Services\Admin\AdminLogger;
use App\Services\NotificationService;
use App\Services\PaymentGateway\PaymentGatewayFactory;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;
use App\Support\CsvSafe;

/**
 * Transactions & litiges. Avant : un litige créait un faux « signalement
 * utilisateur », l'admin ne pouvait ni ouvrir la transaction, ni rembourser,
 * ni trancher, et refundPayment() n'était appelé nulle part.
 */
class AdminTransactionController extends Controller
{
    use AdminHelpers;

    public function __construct(private NotificationService $notif) {}

    public function index(Request $request): JsonResponse
    {
        return response()->json($this->filtered($request)->paginate($this->perPage($request, 20, 100)));
    }

    public function show(Transaction $transaction): JsonResponse
    {
        $transaction->load([
            'buyer:id,full_name,username,email,phone_number,trust_score,account_status',
            'seller:id,full_name,username,email,phone_number,trust_score,account_status',
            'product' => fn ($q) => $q->withTrashed()->select('id', 'title', 'slug', 'price', 'user_id', 'poster_url', 'images', 'deleted_at'),
        ]);

        return response()->json([
            'transaction' => $transaction,
            'reports' => UserReport::where('description', 'like', "[Transaction {$transaction->id}]%")
                ->with('reporter:id,full_name')->latest()->get(),
            'history' => AdminActionLog::where('target_type', 'Transaction')->where('target_id', $transaction->id)
                ->with('admin:id,full_name')->latest()->get(),
            'has_conversation' => $this->findConversation($transaction) !== null,
        ]);
    }

    /**
     * Conversation entre acheteur et vendeur : consultable UNIQUEMENT dans le
     * cadre d'un litige, et chaque consultation est journalisée.
     */
    public function conversation(Request $request, Transaction $transaction): JsonResponse
    {
        if ($transaction->order_status !== 'disputed') {
            return response()->json(['message' => "La conversation n'est consultable que pour un litige ouvert."], 403);
        }

        $conversation = $this->findConversation($transaction);
        if (!$conversation) {
            return response()->json(['messages' => []]);
        }

        AdminLogger::log($request->user(), 'conversation_viewed', 'Transaction', $transaction->id, [
            'conversation_id' => $conversation->id,
        ], 'warning');

        $messages = $conversation->messages()->with('sender:id,full_name')->limit(300)
            ->get(['id', 'sender_id', 'body', 'type', 'created_at']);

        return response()->json(['conversation_id' => $conversation->id, 'messages' => $messages]);
    }

    /**
     * Décision sur un litige : refund (rembourse via la passerelle), release
     * (libère : transaction terminée) ou cancel (annule sans remboursement).
     */
    public function resolveDispute(Request $request, Transaction $transaction): JsonResponse
    {
        $validated = $request->validate([
            'decision' => ['required', 'in:refund,release,cancel'],
            'reason' => $this->reasonRules(),
        ]);

        if ($transaction->order_status !== 'disputed') {
            return response()->json(['message' => "Cette transaction n'est pas en litige."], 422);
        }

        $decision = $validated['decision'];
        $refundMessage = null;

        if ($decision === 'refund') {
            if ($transaction->payment_status !== 'completed') {
                return response()->json(['message' => "Aucun paiement encaissé à rembourser."], 422);
            }
            if (!$transaction->payment_gateway_id || !$transaction->payment_method) {
                return response()->json(['message' => 'Référence de paiement introuvable : remboursement impossible automatiquement.'], 422);
            }

            try {
                $gateway = PaymentGatewayFactory::create($transaction->payment_method);
                $result = $gateway->refundPayment($transaction->payment_gateway_id, (float) $transaction->amount);
            } catch (\Throwable $e) {
                logger()->error('Remboursement échoué', ['transaction' => $transaction->id, 'error' => $e->getMessage()]);
                AdminLogger::log($request->user(), 'refund_failed', 'Transaction', $transaction->id, ['error' => $e->getMessage()], 'critical');

                return response()->json(['message' => 'Le remboursement a échoué côté passerelle de paiement.'], 502);
            }

            if (!($result['success'] ?? false)) {
                AdminLogger::log($request->user(), 'refund_failed', 'Transaction', $transaction->id, ['gateway' => $result['message'] ?? null], 'critical');

                return response()->json([
                    'message' => 'Remboursement refusé par la passerelle.',
                    'gateway_message' => $result['message'] ?? null,
                ], 502);
            }
        }

        DB::transaction(function () use ($transaction, $decision, $validated, $request) {
            match ($decision) {
                'refund' => $transaction->update([
                    'payment_status' => 'refunded', 'order_status' => 'cancelled', 'security_check' => 'passed',
                ]),
                'release' => $transaction->update([
                    'order_status' => 'completed', 'security_check' => 'passed', 'completed_at' => now(),
                ]),
                'cancel' => $transaction->update([
                    'order_status' => 'cancelled', 'security_check' => 'passed',
                ]),
            };

            UserReport::where('description', 'like', "[Transaction {$transaction->id}]%")
                ->where('status', 'pending')
                ->update([
                    'status' => 'resolved', 'reviewed_by' => $request->user()->id,
                    'action_taken' => $decision, 'resolved_at' => now(),
                    'admin_notes' => $validated['reason'],
                ]);

            AdminLogger::log($request->user(), 'dispute_' . $decision, 'Transaction', $transaction->id, [
                'reason' => $validated['reason'], 'amount' => $transaction->amount,
            ], 'critical');
        });

        $labels = [
            'refund' => 'Le litige est tranché : vous êtes remboursé.',
            'release' => 'Le litige est tranché : la transaction est validée.',
            'cancel' => 'Le litige est tranché : la transaction est annulée.',
        ];
        foreach ([$transaction->buyer_id, $transaction->seller_id] as $uid) {
            $this->notif->notifyAdmin($uid, 'Litige résolu', $labels[$decision] . ' ' . $validated['reason'], null, ['kind' => 'dispute_resolved']);
        }

        return response()->json(['message' => 'Litige tranché.', 'transaction' => $transaction->fresh()]);
    }

    /** Export CSV (flux, 50 000 lignes max) pour la comptabilité. */
    public function export(Request $request): StreamedResponse
    {
        $query = $this->filtered($request, false)->limit(50000);

        AdminLogger::log($request->user(), 'transactions_exported', null, null, $request->query());

        return response()->streamDownload(function () use ($query) {
            $out = fopen('php://output', 'w');
            fwrite($out, "\xEF\xBB\xBF");
            fputcsv($out, ['id', 'date', 'acheteur', 'vendeur', 'produit', 'montant', 'commission', 'moyen', 'paiement', 'commande', 'verif'], ';');

            $query->with(['buyer:id,full_name', 'seller:id,full_name', 'product' => fn ($q) => $q->withTrashed()->select('id', 'title')])
                ->chunkById(500, function ($rows) use ($out) {
                    foreach ($rows as $t) {
                        // CsvSafe : noms et titres sont saisis par les utilisateurs (injection de formule Excel).
                        fputcsv($out, CsvSafe::row([
                            $t->id, $t->created_at, $t->buyer->full_name ?? '', $t->seller->full_name ?? '',
                            $t->product->title ?? '', $t->amount, $t->transaction_fee, $t->payment_method,
                            $t->payment_status, $t->order_status, $t->security_check,
                        ]), ';');
                    }
                }, 'id');

            fclose($out);
        }, 'quinch-transactions-' . now()->format('Ymd-His') . '.csv', ['Content-Type' => 'text/csv; charset=UTF-8']);
    }

    private function filtered(Request $request, bool $eager = true)
    {
        $query = Transaction::query();

        if ($eager) {
            $query->with([
                'buyer:id,full_name,username', 'seller:id,full_name,username',
                'product' => fn ($q) => $q->withTrashed()->select('id', 'title', 'slug'),
            ]);
        }

        if ($v = $request->query('payment_status')) $query->where('payment_status', $v);
        if ($v = $request->query('order_status')) $query->where('order_status', $v);
        if ($v = $request->query('payment_method')) $query->where('payment_method', $v);
        if ($v = $request->query('user_id')) $query->where(fn ($q) => $q->where('buyer_id', $v)->orWhere('seller_id', $v));
        if ($request->query('disputed') === '1') $query->where('order_status', 'disputed');
        if ($request->filled('from')) $query->where('created_at', '>=', $request->query('from'));
        if ($request->filled('to')) $query->where('created_at', '<=', $request->query('to') . ' 23:59:59');
        if ($request->filled('min_amount')) $query->where('amount', '>=', (float) $request->query('min_amount'));
        if ($q = trim((string) $request->query('search', ''))) {
            $query->where(fn ($w) => $w->whereRaw('id::text ILIKE ?', [$this->likeTerm($q)])->orWhere('payment_gateway_id', 'ILIKE', $this->likeTerm($q)));
        }

        return $query->orderByDesc('created_at');
    }

    private function findConversation(Transaction $t): ?Conversation
    {
        return Conversation::where(function ($q) use ($t) {
            $q->where(fn ($w) => $w->where('buyer_id', $t->buyer_id)->where('seller_id', $t->seller_id))
              ->orWhere(fn ($w) => $w->where('buyer_id', $t->seller_id)->where('seller_id', $t->buyer_id));
        })->orderByDesc('last_message_at')->first();
    }
}
