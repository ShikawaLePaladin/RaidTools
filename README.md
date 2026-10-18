# RaidTools

Addon de gestion de raid pour **WoW 1.12** (OctoWoW / TurtleWoW), en **deux versions** : une pour les officiers, une pour les joueurs.

> ## ⚠️ BÊTA
> **RaidTools 5 est en bêta.** Il passe des tests automatiques (une simulation de l'API WoW 1.12), mais il n'a pas encore été éprouvé en vrai raid par beaucoup de monde.
> Attends-toi à des bugs d'affichage, des fonctions incomplètes et des changements d'une version à l'autre.
> **La version Membre en particulier est toute récente.** Si quelque chose te semble cassé ou bizarre, ouvre un ticket dans l'onglet [Issues](../../issues) avec ce que tu as vu : c'est exactement ce qui aide à la stabiliser.

*English summary at the bottom of this page.*

---

## Quelle version installer ?

| | **RaidTools — Officier** | **RaidTools Membre** |
|---|---|---|
| Pour qui | Chef de raid, assistants, officiers | Tous les joueurs du raid |
| Dossier à installer | `rt` | `RaidToolsMembre` |
| Commande | `/rt` (ou `/raidtool`) | `/rtm` (ou `/raidmembre`) |
| Ce que tu peux faire | Tout : gérer le roster, les rôles, les groupes, les assignations, l'import du plan, **envoyer le plan au raid** | **Recevoir** le plan et le consulter : schéma du boss en grand, ton rôle, tes tâches, la stratégie |
| Données sauvegardées | `RT_DB` | `RTM_DB` |

**N'installe pas les deux ensemble** : si le dossier `rt` est présent, la version Membre se désactive toute seule.

## Installation

1. Télécharge le zip qui te correspond dans la page **[Releases](../../releases)** :
   - `RaidTools-Officier-…zip` (contient le dossier `rt`)
   - `RaidTools-Membre-…zip` (contient le dossier `RaidToolsMembre`)
2. Dézippe le dossier dans `<ton jeu>\Interface\AddOns\`
3. Relance le jeu (ou `/reload`).

Les joueurs peuvent aussi télécharger la version Membre sur le site : **https://octofan.vercel.app/raidtools/**

## Comment ça marche ensemble

1. L'officier prépare le plan de raid avec l'outil **[Raid](https://octofan.vercel.app/raid/)** du site OctoFan (roster, rôles, assignations par boss, schémas).
2. Il l'importe dans son **RaidTools** (boutons « RaidTools » / « Fichier addon » du site, onglet OctoFan du jeu).
3. Il clique **Envoyer** : le plan est relayé au raid. Seul le chef de raid ou un assistant peut envoyer, et chaque envoi est vérifié côté réception.
4. Les joueurs qui ont **RaidTools Membre** le reçoivent tout seuls, sans rien importer : leur rôle, le schéma du boss et la stratégie s'affichent.

## Version Membre

- **Page Raid** (bouton de la minimap ou `/rtm`) : le schéma du boss en grand avec le nom des joueurs, toutes les assignations (clic = cibler, clic droit = chuchoter), ton rôle, la stratégie.
- **Deux overlays** au choix (clic droit sur le bouton de la minimap) : **Récap** (ton nom, ton rôle, le boss courant, tes tâches) ou **Mon rôle** (une pastille avec ton poste en gros).
- Commandes : `/rtm` · `/rtm recap` · `/rtm role` · `/rtm off` · `/rtm info` (état du plan reçu) · `/rtm reset` (efface ton plan local) · `/rtmtest` (auto-test de l'installation).

## Version Officier

Le RaidTools complet : roster et détection des spécialisations, rôles automatiques, groupes optimisés (Windfury, casters, heals), assignations par boss, annonces de raid, auto-invite, recrutement (LFM), WhisperBot PUG, pull timer, suivi des consommables et du loot, plus la page Raid avec les schémas de boss et l'import / l'envoi du plan.

Commandes utiles : `/rt` (ouvre le panneau) · `/rtselftest` (auto-test) · `/rtrelay` (état du relais du plan).

## Limites connues (bêta)

- **Pas de base de stratégies intégrée.** Les stratégies de boss qui venaient de [Tactica](https://github.com/Player-Doite/tactica) (Player-Doite) ne sont **pas** livrées dans ces versions : la licence de Tactica n'autorise pas la redistribution sans l'accord de l'auteur. Le panneau *Tactics* démarre donc vide ; tu peux y ajouter tes propres tactiques, et les stratégies du plan reçu s'affichent normalement.
- La **présence** (qui était là, à quel kill) n'est pas encore envoyée au site.
- Les schémas et leurs images viennent du site Raid ; seuls les boss de Molten Core ont une image pour l'instant.
- Le code est écrit pour le client 1.12 ; il a été validé par simulation, pas sur tous les serveurs ni tous les réglages d'interface.

## Signaler un problème

Ouvre un ticket dans **[Issues](../../issues)** en indiquant : la version (Officier ou Membre), ce que tu faisais, le message d'erreur s'il y en a un, et si tu avais d'autres addons actifs. `/rtselftest` (officier) ou `/rtmtest` (membre) donne un diagnostic rapide à coller dans le ticket.

## Contenu du dépôt

| Dossier | Contenu |
|---|---|
| `officier/rt` | L'addon complet pour les officiers |
| `membre/RaidToolsMembre` | L'addon pour les joueurs |
| `legacy-v3` | L'ancienne version 3 (juillet), conservée telle quelle pour mémoire |

## Crédits et licence

- Auteur : **ShikawaLePaladin**. Conçu pour [OctoWoW](https://octowow.com) / [TurtleWoW](https://turtle-wow.org) (WoW 1.12.1).
- Le panneau *Tactics* et le recrutement LFM sont *inspirés de* **Tactica** (Player-Doite) ; aucun code ni contenu de Tactica n'est inclus dans les versions 5.
- Les formats d'import Raid-Helper (Composition Tool / Sign-ups) et SoftRes.it sont lus tels quels ; ces services appartiennent à leurs auteurs.
- **Aucune licence n'a encore été choisie** pour ce dépôt. Utilisation personnelle en jeu bienvenue ; pour toute autre réutilisation, demande d'abord.

---

## English summary

**RaidTools** is a raid-management addon for **WoW 1.12** (OctoWoW / TurtleWoW) in **two builds**:

- **Officer** (`rt`, `/rt`): the full tool — roster, auto-roles, groups, boss assignments, plan import and **sending the plan to the raid**.
- **Member** (`RaidToolsMembre`, `/rtm`): players **receive** the plan automatically and see their role, the boss diagram and the strategy. Do not install both: the Member build disables itself if `rt` is loaded.

**⚠️ This is a BETA.** It passes automated tests against a simulated 1.12 API but has not been proven in many real raids yet; the Member build is brand new. Please report problems in [Issues](../../issues).

Download the zips from [Releases](../../releases) (or the Member build from https://octofan.vercel.app/raidtools/), unzip into `Interface\AddOns\`, then `/reload`.
The built-in boss strategy database that came from Tactica is **not** included (its license forbids redistribution without the author's permission); the Tactics panel starts empty and supports your own tactics. No license has been chosen yet.
