<?php

namespace App\Services\Sms;

use InvalidArgumentException;
use RuntimeException;
use Throwable;

/**
 * Envoi de SMS avec bascule automatique : le fournisseur principal d'abord,
 * puis le fournisseur de secours s'il échoue.
 *
 * - Chaque tentative est enregistrée (fournisseur, succès/échec, durée) via le
 *   « recorder » — jamais le texte du message, donc jamais le code OTP.
 * - Un disjoncteur évite de réessayer pendant quelques instants un fournisseur
 *   qui vient d'échouer, tant qu'un autre est disponible.
 * - Si TOUS les fournisseurs échouent, une exception est levée : SendSmsJob
 *   réessaie (délais 5 s puis 30 s).
 *
 * Limite assumée : si un fournisseur a accepté le SMS mais répond en erreur
 * (timeout), le secours renverra le même message : l'utilisateur peut recevoir
 * deux fois le même code, ce qui est sans danger (même code).
 */
class ResilientSmsGateway implements SmsGateway
{
    /** @var callable(string, bool, string, ?string, int): void */
    private $recorder;

    /**
     * @param array<string, SmsGateway> $gateways nom => passerelle, par ordre de priorité
     * @param callable(string $provider, bool $ok, string $to, ?string $error, int $durationMs): void $recorder
     */
    public function __construct(
        private array $gateways,
        private SmsProviderBreaker $breaker,
        callable $recorder,
    ) {
        if ($gateways === []) {
            throw new InvalidArgumentException('Au moins un fournisseur SMS est requis.');
        }

        $this->recorder = $recorder;
    }

    /** @return array<int, string> */
    public function providerNames(): array
    {
        return array_keys($this->gateways);
    }

    public function send(string $to, string $message): void
    {
        $errors = [];

        foreach ($this->candidates() as $name => $gateway) {
            $start = hrtime(true);

            try {
                $gateway->send($to, $message);
            } catch (Throwable $e) {
                $error = self::sanitize($e);
                $errors[] = "{$name}: {$error}";

                $this->breaker->trip($name);
                $this->record($name, false, $to, $error, $this->elapsedMs($start));

                continue;
            }

            $this->breaker->clear($name);
            $this->record($name, true, $to, null, $this->elapsedMs($start));

            return;
        }

        throw new RuntimeException('Aucun fournisseur SMS n\'a pu envoyer le message (' . implode(' ; ', $errors) . ').');
    }

    /**
     * Fournisseurs à essayer : ceux dont le disjoncteur est fermé ; si tous sont
     * ouverts, on les essaie quand même tous (mieux vaut tenter que renoncer).
     *
     * @return array<string, SmsGateway>
     */
    private function candidates(): array
    {
        $available = [];
        foreach ($this->gateways as $name => $gateway) {
            if (!$this->breaker->isOpen($name)) {
                $available[$name] = $gateway;
            }
        }

        return $available !== [] ? $available : $this->gateways;
    }

    private function record(string $provider, bool $ok, string $to, ?string $error, int $ms): void
    {
        try {
            ($this->recorder)($provider, $ok, $to, $error, $ms);
        } catch (Throwable) {
            // Le suivi ne doit JAMAIS empêcher l'envoi d'un code OTP.
        }
    }

    private function elapsedMs(int|float $start): int
    {
        return (int) ((hrtime(true) - $start) / 1_000_000);
    }

    /** Message d'erreur court, sans URL ni donnée sensible. */
    private static function sanitize(Throwable $e): string
    {
        $message = (string) preg_replace('#https?://\S+#i', '[url]', $e->getMessage());
        $short = (new \ReflectionClass($e))->getShortName();

        return mb_substr("{$short}: {$message}", 0, 200);
    }
}
