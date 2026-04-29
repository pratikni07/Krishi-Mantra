# Design system primitives

The pieces below are the canonical building blocks. New screens should
prefer these over inline Material widgets so visual consistency happens
by default.

## Colours — `lib/core/constants/colors.dart` (`AppColors`)

Canonical names: `green`, `lightGreen`, `orange`, `textDark`, `textGrey`,
`textLight`, `textMuted`, `borderLight`, `divider`, `error`, `success`,
`warning`, `info`, `disabled`, `inputFill`, `inputBorder`. **Don't** use
`AppColors.primary` or `AppColors.textPrimary` — those names don't
exist; reach for `green` and `textDark` respectively. (The IoT widget
that mistakenly used those was a long-running compile error before the
Phase 10 sweep.)

## Shadows — `lib/core/theme/app_shadows.dart` (`AppShadows`)

| Token              | When to use                                     |
| ------------------ | ----------------------------------------------- |
| `AppShadows.hairline` | Chips, pills — just a hint of depth.        |
| `AppShadows.low`      | Resting cards, list tiles.                   |
| `AppShadows.medium`   | Buttons, primary surfaces, sheets.           |
| `AppShadows.high`     | FAB, bottom sheets, modal overlays.          |

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    boxShadow: AppShadows.low,
  ),
);
```

## Buttons — `lib/presentation/widgets/primary_button.dart`

```dart
PrimaryButton(label: 'Save', onPressed: _save);                 // solid
PrimaryButton.outline(label: 'Cancel', onPressed: _cancel);     // outlined
PrimaryButton(label: 'Continue', onPressed: _go, isLoading: _busy);
PrimaryButton(label: 'Add', onPressed: _add, icon: Icons.add, fullWidth: false);
```

Disabled state, loading spinner, and icon spacing are all handled —
don't reimplement them.

## Search — `lib/presentation/widgets/app_search_bar.dart`

```dart
AppSearchBar(
  hintText: 'Search products',
  onChanged: (q) => _controller.search(q),
  // 250ms debounce by default; override via `debounce:` if needed.
);
```

## Deprecated `withOpacity` migration

Flutter 3.27+ deprecated `Color.withOpacity` in favour of
`Color.withValues(alpha: x)` to avoid precision loss. The runtime
behaviour is identical for our use cases.

A bulk migration sweep is straightforward but noisy
(261 call sites at last count). A focused approach: when editing a file
for any other reason, also replace its `withOpacity(x)` calls with
`withValues(alpha: x)`. The IoT showcase + state widgets have been
done already as part of Phase 10.

For a one-shot sweep:

```sh
cd Frontend/krishimantra
# Preview only — review the diff before applying.
grep -rln 'withOpacity' lib/ | while read f; do
  sed -i.bak -E 's/withOpacity\(([^)]+)\)/withValues(alpha: \1)/g' "$f"
done
find lib -name '*.bak' -delete
flutter analyze
```

This is mechanical and safe; the only caveat is that any non-numeric
argument (e.g. `withOpacity(_animation.value)`) maps cleanly because
`withValues(alpha:)` takes the same `double`.
