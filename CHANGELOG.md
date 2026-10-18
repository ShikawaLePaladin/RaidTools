# Changelog

## 5.0.0 (officier) / 5.1.0-membre — bêta 1 — 2026-10-18

Première publication de la version 5, **en bêta**.

### Nouveau
- **Deux versions** : `rt` (Officier, 5.0.0) et `RaidToolsMembre` (Membre, 5.1.0-membre), construites à partir de la même source.
- **Page Raid** avec le schéma du boss en grand (noms des joueurs, assignations, rôle, stratégie, phases P1/P2/P3, image de fond, taille grande/compacte, lien vers le schéma du site).
- **Relais du plan** : le chef de raid ou un assistant envoie le plan, les joueurs qui ont la version Membre le reçoivent sans rien importer. Chaque envoi est contrôlé côté réception.
- **Version Membre** : page Raid, overlays *Récap* et *Mon rôle*, commandes `/rtm`.
- Édition personnelle des schémas (déplacer / masquer / ajouter) stockée localement.
- Images de schéma pour les boss de Molten Core.
- Auto-tests `/rtselftest` (officier) et `/rtmtest` (membre).

### Changé
- L'ancienne version 3 est conservée dans `legacy-v3/`.
- **La base de stratégies issue de Tactica n'est plus livrée** (licence de Tactica : pas de redistribution sans accord de l'auteur). Le panneau *Tactics* démarre vide et accepte tes tactiques perso.

### Limites connues
- Bêta : validé par simulation de l'API 1.12, pas encore éprouvé en raid par beaucoup de joueurs.
- La présence (kills / participants) n'est pas encore envoyée au site.
