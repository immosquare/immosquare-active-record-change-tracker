# CLAUDE.md

Gem de tracking automatique des changements ActiveRecord. Enregistre les modifications d'attributs (create/update/destroy) dans une table polymorphique `active_record_change_trackers`.

## Architecture

| Fichier | Rôle |
|---------|------|
| `lib/immosquare-active-record-change-tracker.rb` | Module principal avec `track_active_record_changes` |
| `lib/.../railtie.rb` | Intégration Rails (extend ActiveRecord) |
| `lib/.../models/history_record.rb` | Modèle `HistoryRecord` pour le stockage |
| `lib/generators/.../install/install_generator.rb` | Générateur de migration |

## Fonctionnement

1. Le modèle appelle `track_active_record_changes` avec options (`:only`, `:except`, block pour modifier)
2. Crée l'association `has_many :history_records` et les callbacks `after_save`/`after_destroy`
3. Compare `previous_changes` et crée un `HistoryRecord` avec le type d'événement

## Points clés

- **Associations polymorphiques** : `recordable` (modèle tracké) et `modifier` (auteur du changement)
- **Paranoia** : gère le soft-delete, `really_destroy!` nettoie l'historique
- **Globalize** : track les attributs traduits avec locale
