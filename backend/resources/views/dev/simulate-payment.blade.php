<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Simulation de paiement Wave</title>
    <style>
        body { font-family: -apple-system, sans-serif; background: #0a0a0f; color: white; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; }
        .card { background: #14141f; border-radius: 20px; padding: 32px; width: 100%; max-width: 360px; text-align: center; }
        .badge { display: inline-block; background: rgba(245,158,11,0.15); color: #f59e0b; padding: 6px 14px; border-radius: 20px; font-size: 0.75rem; font-weight: 700; margin-bottom: 16px; }
        h1 { font-size: 1.3rem; margin: 0 0 4px; }
        .amount { font-size: 2rem; font-weight: 800; margin: 16px 0; color: #6366f1; }
        p { color: rgba(255,255,255,0.5); font-size: 0.85rem; }
        form { margin-top: 24px; display: flex; flex-direction: column; gap: 10px; }
        button { padding: 14px; border-radius: 12px; border: none; font-weight: 700; font-size: 0.9rem; cursor: pointer; }
        .btn-success { background: #22c55e; color: white; }
        .btn-error { background: rgba(255,255,255,0.08); color: white; }
    </style>
</head>
<body>
    <div class="card">
        <span class="badge">⚠ MODE SIMULATION — PAS DE VRAI PAIEMENT</span>
        <h1>Paiement Wave</h1>
        <p>Référence : {{ $reference }}</p>
        <div class="amount">{{ number_format((float) $amount, 0, ',', ' ') }} F CFA</div>

        <form method="POST" action="{{ url('/dev/simulate-payment/confirm') }}">
            @csrf
            <input type="hidden" name="reference" value="{{ $reference }}">
            <input type="hidden" name="success_url" value="{{ $successUrl }}">
            <input type="hidden" name="error_url" value="{{ $errorUrl }}">
            <input type="hidden" name="outcome" value="success">
            <button type="submit" class="btn-success" onclick="this.form.outcome.value='success'">✓ Simuler un paiement réussi</button>
        </form>
        <form method="POST" action="{{ url('/dev/simulate-payment/confirm') }}">
            @csrf
            <input type="hidden" name="reference" value="{{ $reference }}">
            <input type="hidden" name="success_url" value="{{ $successUrl }}">
            <input type="hidden" name="error_url" value="{{ $errorUrl }}">
            <input type="hidden" name="outcome" value="error">
            <button type="submit" class="btn-error">✗ Simuler un échec</button>
        </form>
    </div>
</body>
</html>
