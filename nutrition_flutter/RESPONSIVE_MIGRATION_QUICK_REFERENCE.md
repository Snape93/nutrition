# Responsive Migration Quick Reference Guide

## Quick Lookup Table

### Padding Replacements

| Old Pattern | New Pattern |
|------------|-------------|
| `EdgeInsets.all(isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 20))` | `AppDesignSystem.getResponsivePadding(context, horizontal: AppDesignSystem.spaceMD, vertical: AppDesignSystem.spaceMD)` |
| `EdgeInsets.symmetric(horizontal: isNarrowScreen ? 8 : 16)` | `AppDesignSystem.getResponsivePadding(context, horizontal: AppDesignSystem.spaceMD)` |
| `EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 16)` | `AppDesignSystem.getResponsivePadding(context, vertical: AppDesignSystem.spaceMD)` |

### Spacing Replacements

| Old Pattern | New Pattern |
|------------|-------------|
| `SizedBox(height: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24))` | `SizedBox(height: AppDesignSystem.getResponsiveSpacing(context, xs: AppDesignSystem.spaceMD, sm: AppDesignSystem.spaceLG, md: AppDesignSystem.spaceXL))` |
| `SizedBox(width: isNarrowScreen ? 8 : 16)` | `SizedBox(width: AppDesignSystem.getResponsiveSpacing(context))` |

### Font Size Replacements

| Old Pattern | New Pattern |
|------------|-------------|
| `fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 15 : 16)` | `AppDesignSystem.getResponsiveFontSize(context, xs: 14, sm: 15, md: 16)` |
| `fontSize: isVerySmallScreen ? 22 : (isSmallScreen ? 25 : 28)` | `AppDesignSystem.getResponsiveFontSize(context, xs: 22, sm: 25, md: 28)` |

### Input Field Padding

| Old Pattern | New Pattern |
|------------|-------------|
| `contentPadding: EdgeInsets.symmetric(horizontal: isVerySmallScreen ? 12 : 16, vertical: isVerySmallScreen ? 10 : 12)` | `contentPadding: AppDesignSystem.getResponsivePadding(context, horizontal: AppDesignSystem.spaceMD, vertical: AppDesignSystem.spaceSM)` |

---

## Common Scenarios

### Scenario 1: Screen-Level Padding
```dart
// SingleChildScrollView padding
padding: AppDesignSystem.getResponsivePadding(
  context,
  horizontal: AppDesignSystem.spaceMD,  // 16px base
  vertical: AppDesignSystem.spaceMD,    // 16px base
)
```

### Scenario 2: Card/Container Padding
```dart
// Container padding
padding: AppDesignSystem.getResponsivePadding(
  context,
  horizontal: AppDesignSystem.spaceMD,
  vertical: AppDesignSystem.spaceMD,
)
```

### Scenario 3: Section Spacing
```dart
// Space between sections
SizedBox(
  height: AppDesignSystem.getResponsiveSpacing(
    context,
    xs: AppDesignSystem.spaceMD,   // 16px on very small
    sm: AppDesignSystem.spaceLG,   // 24px on small
    md: AppDesignSystem.spaceXL,   // 32px on medium+
  ),
)
```

### Scenario 4: Element Spacing
```dart
// Space between related elements
SizedBox(
  height: AppDesignSystem.getResponsiveSpacing(
    context,
    xs: AppDesignSystem.spaceSM,   // 8px on very small
    sm: AppDesignSystem.spaceMD,   // 16px on small+
  ),
)
```

### Scenario 5: Button Padding
```dart
// Button padding
padding: AppDesignSystem.getResponsivePadding(
  context,
  horizontal: AppDesignSystem.spaceLG,  // 24px base
  vertical: AppDesignSystem.spaceMD,    // 16px base
)
```

### Scenario 6: Input Field
```dart
// Input decoration
decoration: InputDecoration(
  contentPadding: AppDesignSystem.getResponsivePadding(
    context,
    horizontal: AppDesignSystem.spaceMD,
    vertical: AppDesignSystem.spaceSM,
  ),
  // ... other properties
)
```

---

## Spacing Constants Reference

| Constant | Value | Use Case |
|----------|-------|----------|
| `spaceXS` | 4px | Minimal spacing, tight layouts |
| `spaceSM` | 8px | Small gaps, icon spacing |
| `spaceMD` | 16px | Standard spacing, default padding |
| `spaceLG` | 24px | Section spacing, button padding |
| `spaceXL` | 32px | Large section spacing |
| `spaceXXL` | 48px | Extra large spacing, major sections |

---

## Screen Size Breakpoints

| Breakpoint | Width | Category |
|------------|-------|----------|
| Very Small | < 360px | Small phones |
| Small | 360-600px | Standard phones |
| Medium | 600-900px | Large phones, small tablets |
| Large | > 900px | Tablets, desktop |

---

## Migration Checklist Per File

### Pre-Migration
- [ ] Backup current file
- [ ] Review all hard-coded responsive logic
- [ ] Identify all padding instances
- [ ] Identify all spacing instances
- [ ] Identify all font size instances

### During Migration
- [ ] Add import: `import '../design_system/app_design_system.dart';`
- [ ] Remove old screen size variables (`isSmallScreen`, etc.)
- [ ] Replace all padding instances
- [ ] Replace all spacing instances
- [ ] Replace all font size instances
- [ ] Replace input field padding
- [ ] Replace container padding

### Post-Migration
- [ ] Test on small phone (< 360px)
- [ ] Test on standard phone (360-600px)
- [ ] Test on large phone/tablet (> 600px)
- [ ] Test in landscape mode
- [ ] Verify no overflow issues
- [ ] Verify touch targets are adequate
- [ ] Check text readability

---

## Common Patterns in enhanced_onboarding_physical.dart

### Pattern 1: Screen Padding (Line ~308)
```dart
// OLD
padding: EdgeInsets.symmetric(
  horizontal: isNarrowScreen ? 8 : (isSmallScreen ? 12 : 16),
  vertical: isVerySmallScreen ? 8 : (isSmallScreen ? 12 : 16),
)

// NEW
padding: AppDesignSystem.getResponsivePadding(
  context,
  horizontal: AppDesignSystem.spaceMD,
  vertical: AppDesignSystem.spaceMD,
)
```

### Pattern 2: Container Padding (Line ~432)
```dart
// OLD
padding: EdgeInsets.all(
  isVerySmallScreen ? 12 : (isSmallScreen ? 16 : 20),
)

// NEW
padding: AppDesignSystem.getResponsivePadding(
  context,
  horizontal: AppDesignSystem.spaceMD,
  vertical: AppDesignSystem.spaceMD,
)
```

### Pattern 3: Spacing (Line ~324)
```dart
// OLD
SizedBox(
  height: isVerySmallScreen ? 16 : (isSmallScreen ? 20 : 24),
)

// NEW
SizedBox(
  height: AppDesignSystem.getResponsiveSpacing(
    context,
    xs: AppDesignSystem.spaceMD,
    sm: AppDesignSystem.spaceLG,
    md: AppDesignSystem.spaceXL,
  ),
)
```

### Pattern 4: Font Size (Line ~451)
```dart
// OLD
fontSize: isVerySmallScreen ? 36 : (isSmallScreen ? 42 : 48),

// NEW
fontSize: AppDesignSystem.getResponsiveFontSize(
  context,
  xs: 36,
  sm: 42,
  md: 48,
)
```

### Pattern 5: Input Padding (Line ~674)
```dart
// OLD
contentPadding: EdgeInsets.symmetric(
  horizontal: isVerySmallScreen ? 12 : 16,
  vertical: isVerySmallScreen ? 10 : 12,
)

// NEW
contentPadding: AppDesignSystem.getResponsivePadding(
  context,
  horizontal: AppDesignSystem.spaceMD,
  vertical: AppDesignSystem.spaceSM,
)
```

---

## Tips & Best Practices

1. **Always use context**: All responsive methods require `BuildContext`
2. **Be consistent**: Use the same spacing constants for similar elements
3. **Test incrementally**: Test after migrating each major section
4. **Use constants**: Prefer `AppDesignSystem.spaceMD` over magic numbers
5. **Consider content**: Adjust spacing based on content density
6. **Touch targets**: Ensure buttons/inputs are at least 44x44px
7. **Text scale**: Consider using `MediaQuery.textScaleFactor` for accessibility

---

## Troubleshooting

### Issue: Padding looks too large/small
**Solution**: Adjust the base values in `getResponsivePadding` call

### Issue: Spacing inconsistent
**Solution**: Use the same spacing constants for similar elements

### Issue: Text too small on large screens
**Solution**: Increase the `md` or `lg` values in `getResponsiveFontSize`

### Issue: Content overflow
**Solution**: 
- Use `SingleChildScrollView` for scrollable content
- Reduce padding on very small screens
- Consider using `Flexible` or `Expanded` widgets

---

## Quick Copy-Paste Templates

### Template 1: Standard Padding
```dart
padding: AppDesignSystem.getResponsivePadding(
  context,
  horizontal: AppDesignSystem.spaceMD,
  vertical: AppDesignSystem.spaceMD,
)
```

### Template 2: Compact Padding
```dart
padding: AppDesignSystem.getResponsivePadding(
  context,
  horizontal: AppDesignSystem.spaceSM,
  vertical: AppDesignSystem.spaceSM,
)
```

### Template 3: Large Padding
```dart
padding: AppDesignSystem.getResponsivePadding(
  context,
  horizontal: AppDesignSystem.spaceLG,
  vertical: AppDesignSystem.spaceLG,
)
```

### Template 4: Section Spacing
```dart
SizedBox(
  height: AppDesignSystem.getResponsiveSpacing(
    context,
    xs: AppDesignSystem.spaceMD,
    sm: AppDesignSystem.spaceLG,
    md: AppDesignSystem.spaceXL,
  ),
)
```

### Template 5: Responsive Font
```dart
Text(
  'Your Text',
  style: AppDesignSystem.bodyMedium.copyWith(
    fontSize: AppDesignSystem.getResponsiveFontSize(
      context,
      xs: 14,
      sm: 16,
      md: 18,
    ),
  ),
)
```

