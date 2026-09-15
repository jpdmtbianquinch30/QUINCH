<?php

namespace App\Services\PaymentGateway;

/**
 * Paiement en espèces à la livraison ou au retrait.
 *
 * Aucune passerelle externe n'est impliquée et aucun argent ne transite par
 * l'application : acheteur et vendeur se coordonnent physiquement. La
 * transaction est donc créée normalement (pour que la commande existe, que
 * le stock soit réservé et que le suivi acheteur/vendeur fonctionne), mais
 * payment_status reste 'pending' jusqu'à ce que la commande soit menée à son
 * terme via les actions de suivi habituelles (expédié -> livré -> réception
 * confirmée), qui valent confirmation implicite de l'encaissement en main
 * propre.
 */
class CashGateway implements PaymentGatewayInterface
{
    public function initiatePayment(array $request): array
    {
        // Pas d'étape de paiement en ligne : on renvoie directement
        // l'URL de succès. Le frontend fait un window.location.href sur
        // payment_url de façon uniforme quelle que soit la méthode choisie,
        // donc l'acheteur atterrit tout de suite sur le suivi de sa
        // commande, sans redirection vers une passerelle.
        return [
            'success' => true,
            'payment_url' => $request['success_url'] ?? null,
            'gateway_reference' => null,
            'gateway' => 'cash',
        ];
    }

    public function verifyPayment(string $transactionId): array
    {
        // Rien à vérifier auprès d'un tiers : la confirmation se fait
        // physiquement entre les deux parties.
        return ['verified' => true, 'status' => 'manual'];
    }

    public function refundPayment(string $transactionId, float $amount): array
    {
        // Remboursement à effectuer de la main à la main, hors application.
        return [
            'success' => true,
            'message' => 'Remboursement à effectuer en espèces directement avec le client.',
        ];
    }

    public function getName(): string
    {
        return 'Espèces';
    }

    public function getFeeRate(): float
    {
        // Aucune passerelle, donc aucune commission de transaction.
        return 0.0;
    }
}
