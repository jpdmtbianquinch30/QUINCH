<?php

namespace App\Console\Commands;

use App\Mail\MailTestMail;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Mail;
use Throwable;

/**
 * Envoie un VRAI e-mail de test pour valider la configuration SMTP sans passer
 * par un « mot de passe oublié ». Exemples :
 *   php artisan quinch:mail-test vous@gmail.com           (envoi direct : valide le SMTP)
 *   php artisan quinch:mail-test vous@gmail.com --queue   (via la file : valide aussi le worker)
 *
 * N'affiche jamais le mot de passe SMTP.
 */
class QuinchMailTest extends Command
{
    protected $signature = 'quinch:mail-test
        {email : Adresse qui reçoit le message de test}
        {--queue : Passer par la file d\'attente (comme les vrais codes) au lieu d\'un envoi direct}';

    protected $description = 'Envoie un e-mail de test réel pour valider la configuration SMTP';

    public function handle(): int
    {
        $email = strtolower(trim((string) $this->argument('email')));

        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $this->error('Adresse e-mail invalide.');

            return self::FAILURE;
        }

        $mailer = (string) config('mail.default', 'log');

        $this->line("Transport : MAIL_MAILER={$mailer}");
        if ($mailer === 'smtp') {
            $smtp = (array) config('mail.mailers.smtp', []);
            $this->line('Serveur   : ' . ($smtp['host'] ?? '?') . ':' . ($smtp['port'] ?? '?')
                . ' (schéma : ' . (($smtp['scheme'] ?? null) ?: 'auto') . ')');
            $this->line('Identifiants SMTP renseignés : '
                . (!empty($smtp['username']) && !empty($smtp['password']) ? 'oui' : 'NON'));
        }
        $this->line('Expéditeur : ' . (string) config('mail.from.address'));

        if (in_array($mailer, ['log', 'array'], true)) {
            $this->warn("MAIL_MAILER={$mailer} : aucun e-mail réel ne part (le message est écrit dans storage/logs/laravel.log ou ignoré).");
        }

        if ($this->option('queue')) {
            $connection = (string) config('queue.default');

            try {
                Mail::to($email)->queue(new MailTestMail());
            } catch (Throwable $e) {
                $this->error("Mise en file impossible (QUEUE_CONNECTION={$connection}) : " . $this->redact($e->getMessage()));

                return self::FAILURE;
            }

            $this->info($connection === 'sync'
                ? "Message envoyé immédiatement (QUEUE_CONNECTION=sync). Vérifiez la réception sur {$email}."
                : "Message mis en file (connexion « {$connection} »). Il ne partira que si un worker tourne : php artisan queue:work");

            return self::SUCCESS;
        }

        $start = microtime(true);

        try {
            Mail::to($email)->send(new MailTestMail());
        } catch (Throwable $e) {
            $this->error('Échec de l\'envoi : ' . $this->redact($e->getMessage()));
            $this->line('Pistes : MAIL_HOST / MAIL_PORT, MAIL_SCHEME (smtp pour 587, smtps pour 465), identifiants, pare-feu sortant.');

            return self::FAILURE;
        }

        $ms = (int) round((microtime(true) - $start) * 1000);
        $this->info("E-mail accepté par le serveur en {$ms} ms. Vérifiez la réception sur {$email} (et les courriers indésirables).");

        return self::SUCCESS;
    }

    /** Retire toute URL (elle peut contenir des identifiants) d'un message d'erreur. */
    private function redact(string $message): string
    {
        return (string) preg_replace('#[a-z][a-z0-9+.-]*://\S+#i', '[url]', $message);
    }
}
