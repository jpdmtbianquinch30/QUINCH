import { LegalInfo } from '../../core/services/legal.service';

/**
 * Contenu des pages légales de QUINCH.
 *
 * Les informations propres à l'éditeur (nom, adresse, contact, hébergeur, durées de
 * conservation, versions) ne sont JAMAIS écrites ici : elles viennent du serveur
 * (GET /api/v1/legal/info, réglé dans backend/.env). Quand la société sera créée, on
 * change le .env, pas ce fichier. Une information absente s'affiche « [à compléter] ».
 *
 * Ces textes doivent être relus par un juriste avant l'ouverture au public
 * (voir backend/docs/CONFORMITE_LEGALE.md).
 */

export type LegalDocKey = 'cgu' | 'confidentialite' | 'mentions-legales';

export interface LegalSection {
  title: string;
  paragraphs: string[];
}

export interface LegalDocument {
  title: string;
  version: string;
  sections: LegalSection[];
}

export const LEGAL_DOCS: { key: LegalDocKey; label: string; path: string }[] = [
  { key: 'cgu', label: "Conditions d'utilisation", path: '/legal/cgu' },
  { key: 'confidentialite', label: 'Politique de confidentialité', path: '/legal/confidentialite' },
  { key: 'mentions-legales', label: 'Mentions légales', path: '/legal/mentions-legales' },
];

const TODO = '[à compléter]';

function v(value: string | null | undefined): string {
  return value && value.trim() ? value.trim() : TODO;
}

export function buildLegalDocument(key: LegalDocKey, info: LegalInfo | null): LegalDocument {
  switch (key) {
    case 'confidentialite':
      return privacy(info);
    case 'mentions-legales':
      return notice(info);
    default:
      return terms(info);
  }
}

// ─── Mentions légales ───────────────────────────────────────────────────────

function notice(info: LegalInfo | null): LegalDocument {
  const p = info?.publisher;

  return {
    title: 'Mentions légales',
    version: '',
    sections: [
      {
        title: 'Éditeur du service',
        paragraphs: [
          `QUINCH est édité par : ${v(p?.name)}.`,
          `Statut : ${v(p?.status)}.`,
          `Adresse : ${v(p?.address)}.`,
          `Numéro d'immatriculation (NINEA / RCCM) : ${v(p?.registration)}.`,
          `Directeur de la publication : ${v(p?.director)}.`,
          `Contact : ${v(info?.contact_email)}.`,
        ],
      },
      {
        title: 'Hébergement',
        paragraphs: [
          `Le service est hébergé par ${v(info?.hosting.provider)}, sur des serveurs situés en : ${v(info?.hosting.location)}.`,
        ],
      },
      {
        title: 'Propriété intellectuelle',
        paragraphs: [
          "La marque QUINCH, le logo, l'interface et le code du service sont la propriété de leur éditeur. Toute reproduction non autorisée est interdite.",
          "Les photos, vidéos et textes publiés dans les annonces restent la propriété de leurs auteurs, qui accordent à QUINCH les droits décrits dans les conditions d'utilisation.",
        ],
      },
      {
        title: 'Signaler un contenu illicite',
        paragraphs: [
          "Chaque annonce et chaque profil peut être signalé depuis l'application. Vous pouvez aussi écrire à " +
            v(info?.contact_email) +
            " en indiquant le lien du contenu et le motif : il sera examiné et retiré s'il est illicite.",
        ],
      },
      {
        title: 'Données personnelles',
        paragraphs: [
          "Le traitement de vos données personnelles est décrit dans la politique de confidentialité.",
        ],
      },
    ],
  };
}

// ─── Conditions d'utilisation ───────────────────────────────────────────────

function terms(info: LegalInfo | null): LegalDocument {
  const editor = v(info?.publisher.name);
  const contact = v(info?.contact_email);

  return {
    title: "Conditions d'utilisation",
    version: v(info?.versions.terms),
    sections: [
      {
        title: '1. Objet',
        paragraphs: [
          `Les présentes conditions encadrent l'utilisation de QUINCH, service édité par ${editor} (« QUINCH »). En créant un compte, vous déclarez les avoir lues et les acceptez.`,
        ],
      },
      {
        title: '2. Le service',
        paragraphs: [
          "QUINCH est une plateforme de petites annonces illustrées par des vidéos et des photos : des vendeurs y présentent des biens ou des services, et des acheteurs les découvrent, échangent par messages et prennent contact.",
          "QUINCH met en relation. QUINCH n'est pas le vendeur, n'est pas partie aux ventes conclues entre utilisateurs, ne détient pas les marchandises et ne garantit ni leur qualité, ni leur conformité, ni la solvabilité ou l'honnêteté des utilisateurs.",
          "À ce jour, le paiement des biens et services se règle directement entre l'acheteur et le vendeur, en dehors de QUINCH. Si QUINCH proposait un jour un paiement sécurisé des ventes, ces conditions seraient complétées avant toute mise en service.",
        ],
      },
      {
        title: '3. Compte',
        paragraphs: [
          "Pour publier ou écrire à un vendeur, vous créez un compte avec une adresse e-mail valide, ou via votre compte Google.",
          "Le service est réservé aux personnes majeures. Vous vous engagez à fournir des informations exactes, à ne créer qu'un seul compte, à garder votre mot de passe secret et à nous prévenir en cas d'utilisation frauduleuse. Vous êtes responsable de ce qui est fait depuis votre compte.",
          "Vous pouvez supprimer votre compte à tout moment depuis les paramètres (voir la politique de confidentialité).",
        ],
      },
      {
        title: '4. Règles de publication',
        paragraphs: [
          "Vous publiez uniquement des annonces que vous avez le droit de publier, pour des biens ou services réels, avec des descriptions, prix et photos fidèles.",
          "Sont interdits : les produits ou services illégaux, volés, contrefaits ou dangereux (notamment armes, stupéfiants, médicaments sans autorisation) ; les contenus violents, sexuellement explicites, haineux, discriminatoires ou diffamatoires ; les arnaques et fausses annonces ; la publication de données personnelles d'autrui sans son accord ; le contournement des mesures de sécurité ou de modération ; l'envoi massif de messages non sollicités.",
        ],
      },
      {
        title: '5. Vos contenus',
        paragraphs: [
          "Vous restez propriétaire de vos vidéos, photos et textes. Vous accordez à QUINCH, pour la durée de leur publication, le droit non exclusif de les héberger, les afficher, les redimensionner et les diffuser dans le service afin de le faire fonctionner et de le promouvoir en son sein.",
          "Vous garantissez détenir les droits sur ce que vous publiez (et l'accord des personnes reconnaissables sur vos vidéos et photos). Vous êtes seul responsable de vos contenus.",
        ],
      },
      {
        title: '6. Modération et sanctions',
        paragraphs: [
          "Les annonces et profils peuvent être signalés par les utilisateurs et examinés par l'équipe de QUINCH. Un contenu contraire aux présentes conditions ou à la loi peut être masqué ou supprimé.",
          "En cas de manquement, QUINCH peut avertir, suspendre temporairement ou bannir un compte, selon la gravité et la répétition des faits. Vous pouvez contester une décision depuis l'application ou en écrivant à " +
            contact +
            ".",
        ],
      },
      {
        title: '7. Services payants',
        paragraphs: [
          "Certaines fonctions sont payantes : abonnement Premium (mensuel ou annuel) et frais de publication d'annonces. Les prix, en francs CFA (FCFA), sont affichés avant tout paiement.",
          "Les paiements passent par des prestataires tiers (Wave, Orange Money) ; QUINCH ne conserve pas vos identifiants de paiement.",
          "Sauf erreur de facturation, paiement en double ou défaut du service imputable à QUINCH, une période d'abonnement entamée n'est pas remboursée. Écrivez à " +
            contact +
            " pour signaler une erreur.",
        ],
      },
      {
        title: '8. Prudence entre utilisateurs',
        paragraphs: [
          "Avant d'acheter : rencontrez le vendeur dans un lieu public, vérifiez le bien avant de payer, méfiez-vous des prix trop bas et des demandes de paiement à l'avance ou hors du circuit habituel. QUINCH ne peut pas être tenu responsable d'un différend entre utilisateurs, mais peut examiner un signalement.",
        ],
      },
      {
        title: '9. Responsabilité',
        paragraphs: [
          "QUINCH s'efforce d'assurer un service continu mais ne garantit pas l'absence d'interruption ou d'erreur. Dans les limites permises par la loi, QUINCH n'est pas responsable des contenus publiés par les utilisateurs, des transactions conclues entre eux, ni des dommages indirects.",
        ],
      },
      {
        title: '10. Données personnelles',
        paragraphs: [
          "QUINCH traite vos données personnelles comme décrit dans la politique de confidentialité, que vous acceptez en même temps que ces conditions.",
        ],
      },
      {
        title: '11. Modification des conditions',
        paragraphs: [
          "Ces conditions peuvent évoluer. Chaque version porte un numéro ; en cas de changement important, vous en serez informé et, si la loi l'exige, votre accord sera à nouveau demandé.",
        ],
      },
      {
        title: '12. Droit applicable',
        paragraphs: [
          "Ces conditions sont soumises au droit sénégalais. En cas de litige, nous vous invitons d'abord à nous écrire à " +
            contact +
            " pour chercher une solution amiable ; à défaut, les juridictions sénégalaises sont compétentes.",
        ],
      },
    ],
  };
}

// ─── Politique de confidentialité ───────────────────────────────────────────

function privacy(info: LegalInfo | null): LegalDocument {
  const editor = v(info?.publisher.name);
  const rights = v(info?.privacy_email || info?.contact_email);
  const days = info?.retention.anonymized_content_days ?? 30;
  const logDays = info?.retention.audit_logs_days ?? 180;
  const cdp = info?.cdp_receipt?.trim();

  return {
    title: 'Politique de confidentialité',
    version: v(info?.versions.privacy),
    sections: [
      {
        title: '1. Qui est responsable de vos données',
        paragraphs: [
          `Le responsable du traitement est ${editor}, éditeur de QUINCH (coordonnées dans les mentions légales).`,
          `Pour toute question ou pour exercer vos droits : ${rights}.`,
          cdp
            ? `Le traitement a fait l'objet d'une déclaration auprès de la Commission de Protection des Données Personnelles (CDP) du Sénégal, récépissé n° ${cdp}.`
            : "Le traitement est en cours de déclaration auprès de la Commission de Protection des Données Personnelles (CDP) du Sénégal.",
        ],
      },
      {
        title: '2. Les données que nous traitons',
        paragraphs: [
          "Votre compte : nom, nom d'utilisateur, adresse e-mail, mot de passe (conservé uniquement sous forme chiffrée irréversible), photo de profil et de couverture, présentation, ville et région. Si vous vous connectez avec Google : votre nom, votre e-mail et votre photo fournis par Google.",
          "Vos annonces : vidéos, photos, titres, descriptions, prix, catégories.",
          "Vos échanges : messages, avis, signalements, favoris, mentions « j'aime », abonnements à d'autres comptes, négociations.",
          "Vos paiements : références des paiements Premium et des frais d'annonce (montant, date, statut, identifiant fourni par Wave ou Orange Money). Nous ne recevons ni votre code secret, ni votre solde.",
          "Données techniques : adresse IP, type d'appareil et de navigateur, empreinte d'appareil servant à détecter les fraudes, journaux de sécurité (connexions, actions sensibles) et statistiques d'usage de l'application (pages et annonces consultées).",
        ],
      },
      {
        title: '3. Pourquoi, et sur quel fondement',
        paragraphs: [
          "Fournir le service que vous avez demandé (compte, publication, messagerie, paiement Premium) : exécution du contrat.",
          "Sécuriser le service, détecter les fraudes et les abus, modérer les contenus, prouver nos décisions : intérêt légitime de QUINCH et de ses utilisateurs.",
          "Mesurer l'usage de l'application pour l'améliorer : intérêt légitime, sans publicité ciblée.",
          "Tenir la comptabilité et répondre aux demandes des autorités : obligation légale.",
          "Vous prévenir (notifications) et utiliser votre localisation lorsque vous l'activez : votre consentement, que vous pouvez retirer à tout moment.",
          "Nous ne vendons pas vos données et ne les utilisons pas pour de la publicité de tiers.",
        ],
      },
      {
        title: '4. Qui reçoit vos données',
        paragraphs: [
          `Hébergement et stockage : ${v(info?.hosting.provider)}.`,
          "Envoi des e-mails (codes, notifications) : notre prestataire d'envoi d'e-mails.",
          "Paiements : Wave et Orange Money, pour traiter les paiements que vous initiez.",
          "Connexion avec Google : Google, uniquement si vous choisissez ce mode de connexion.",
          "Vos annonces, votre nom d'utilisateur, votre photo et votre présentation sont visibles par les autres utilisateurs. Vos messages ne sont visibles que par leurs destinataires et, en cas de signalement ou d'enquête, par l'équipe de modération.",
          "Les autorités compétentes peuvent obtenir des données sur réquisition légale.",
        ],
      },
      {
        title: '5. Où sont stockées vos données',
        paragraphs: [
          `Les données sont stockées sur des serveurs situés en : ${v(info?.hosting.location)}. Ce stockage hors du Sénégal donne lieu aux formalités prévues par la loi sénégalaise sur la protection des données personnelles auprès de la CDP, et nous choisissons des prestataires offrant un niveau de protection adéquat.`,
        ],
      },
      {
        title: '6. Combien de temps nous les gardons',
        paragraphs: [
          "Tant que votre compte est actif : vos données de compte, annonces et messages.",
          `Si vous supprimez votre compte : votre identité (nom, e-mail, téléphone, localisation, photos de profil) est effacée immédiatement. Vos annonces, vidéos, photos et messages sont masqués, puis effacés définitivement après ${days} jours (délai laissé pour traiter un litige en cours).`,
          "Les données de paiement (montants, dates, références) sont conservées pour la durée imposée par les obligations comptables, sans lien avec votre identité une fois le compte supprimé.",
          `Journaux techniques (adresses IP, appareils, actions de sécurité) : ${logDays} jours.`,
          "Codes de vérification : quelques minutes. Messages et contenus supprimés par vous : effacés selon les mêmes délais.",
        ],
      },
      {
        title: '7. Vos droits',
        paragraphs: [
          "Vous pouvez à tout moment : accéder à vos données, les faire rectifier, vous opposer à certains traitements, demander leur suppression, et les récupérer dans un format réutilisable.",
          "Depuis l'application, dans les paramètres : « Exporter mes données » télécharge tout ce que QUINCH détient sur vous ; « Supprimer mon compte » déclenche l'effacement décrit ci-dessus ; vous pouvez aussi modifier votre profil.",
          `Pour toute autre demande, écrivez à ${rights}. Nous répondons dans un délai maximal de 30 jours.`,
          "Si vous estimez que vos droits ne sont pas respectés, vous pouvez saisir la Commission de Protection des Données Personnelles (CDP) du Sénégal.",
        ],
      },
      {
        title: '8. Sécurité',
        paragraphs: [
          "Les échanges avec QUINCH sont chiffrés (HTTPS). Les mots de passe sont stockés sous forme chiffrée irréversible. L'accès aux données est limité à l'équipe habilitée et les actions sensibles d'administration sont journalisées. Aucun système n'étant infaillible : en cas de violation de données vous concernant, nous vous en informerons et préviendrons la CDP lorsque cela est nécessaire.",
        ],
      },
      {
        title: '9. Stockage dans votre navigateur et cookies',
        paragraphs: [
          "QUINCH n'utilise ni cookie publicitaire, ni traceur de réseaux sociaux. Il enregistre dans votre navigateur uniquement ce qui est nécessaire à son fonctionnement : votre jeton de connexion, vos préférences d'affichage et de recherche, un identifiant de session anonyme pour les statistiques d'usage et un indicateur de bienvenue.",
          "Si vous utilisez la connexion Google, Google peut déposer ses propres cookies selon sa politique.",
        ],
      },
      {
        title: '10. Mineurs',
        paragraphs: [
          "QUINCH est réservé aux personnes majeures. Si vous pensez qu'un mineur a créé un compte, écrivez-nous : nous le supprimerons.",
        ],
      },
      {
        title: '11. Modifications',
        paragraphs: [
          "Cette politique peut évoluer ; chaque version porte un numéro et la version que vous avez acceptée est enregistrée. Nous vous informerons de tout changement important.",
        ],
      },
    ],
  };
}
