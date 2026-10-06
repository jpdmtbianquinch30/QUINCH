<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>QUINCH</title>
</head>
<body style="margin:0;padding:24px;background:#f4f4f5;font-family:Arial,Helvetica,sans-serif;color:#18181b;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;margin:0 auto;background:#ffffff;border-radius:12px;padding:32px;">
        <tr>
            <td>
                <h1 style="margin:0 0 16px;font-size:22px;">QUINCH</h1>
                <p style="margin:0 0 16px;font-size:15px;line-height:1.5;">
                    Vous avez demandé à réinitialiser votre mot de passe. Voici votre code :
                </p>
                <p style="margin:0 0 16px;text-align:center;font-size:32px;font-weight:bold;letter-spacing:8px;">
                    {{ $code }}
                </p>
                <p style="margin:0 0 16px;font-size:14px;line-height:1.5;color:#52525b;">
                    Ce code est valable {{ $minutes }} minutes. Ne le partagez avec personne :
                    l'équipe QUINCH ne vous le demandera jamais.
                </p>
                <p style="margin:0;font-size:14px;line-height:1.5;color:#52525b;">
                    Si vous n'êtes pas à l'origine de cette demande, ignorez ce message : votre mot de passe reste inchangé.
                </p>
            </td>
        </tr>
    </table>
</body>
</html>
