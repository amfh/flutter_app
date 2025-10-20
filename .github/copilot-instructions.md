# Kompetansebiblioteket Flutter App - AI Coding Instructions

## Project Overview
This is a Norwegian B2B Flutter app for VVS (heating, ventilation, sanitation) technical publications. Users authenticate via Azure AD B2C to access role-based educational content including handbooks, technical guides, and reference materials.

## Architecture Patterns

### Authentication & Session Management
- **Singleton Pattern**: `UserSession` class in `main.dart` manages global authentication state
- **Persistent Storage**: All session data (tokens, user info, extension products) saved to `SharedPreferences`
- **Azure B2C Integration**: Uses `aad_b2c_webview` package for OAuth2 authentication flows
- **JWT Token Processing**: Complex token parsing extracts `extension_Products` for access control

```dart
// Key pattern: Always check login status before accessing protected features
final isLoggedIn = await UserSession.instance.isLoggedIn();
```

### Data Models & Access Control
- **Publication Access**: `PublicationAccessService` contains hardcoded mapping of publication titles to allowed product IDs
- **Content Filtering**: Publications filtered based on user's `extensionProducts` from JWT tokens
- **Offline-First**: All content cached locally via `LocalStorageService` for offline reading

### Service Layer Architecture
- **PublicationService**: Main service handling API calls, local caching, and content management
  - `downloadAndCacheContentOnly()`: Basic content download
  - `downloadAndCacheContentOnlyWithProgress()`: Content download with progress callbacks
  - `downloadImagesForCachedPublication()`: Basic image download for cached content
  - `downloadImagesForCachedPublicationWithProgress()`: Image download with progress callbacks
- **LocalStorageService**: File system operations for JSON data and images
- **OfflineDownloadService**: Bulk content downloading for offline access
- **CacheCleanupService**: Manages storage cleanup and optimization
- **UpdateCheckService**: Background checking for publication updates using API UpdateDate field

### UI Navigation Patterns
- **MainScaffold**: Shared app bar with hamburger menu used across all screens
- **AuthWrapper**: Root component that routes between login and main app based on authentication status
- **Screen Pattern**: Each screen is self-contained with its own state management

## Critical Development Workflows

### Content Caching Strategy
```dart
// Download pattern: API → Local Storage → UI consumption
await publicationService.downloadFullContent(publicationId);
await LocalStorageService.writeJson('fullcontent_$publicationId.json', data);
```

### Progress Tracking for Downloads
- **Progress Callbacks**: Download methods support progress tracking with `onProgress` callbacks
- **API Data Size**: Uses `DataSizeInBytes` from API endpoints for accurate progress calculation
- **StatefulBuilder**: Progress dialogs use StatefulBuilder pattern for real-time UI updates

```dart
// Progress-enabled downloads with callback pattern
await _publicationService.downloadAndCacheContentOnlyWithProgress(
  publicationId,
  onProgress: (double progress, String status) {
    dialogSetState(() {
      this.progress = progress; // 0.0 to 1.0
      statusText = status; // Current operation description
    });
  },
);
```

### HTML Content Rendering
- Uses `flutter_html` for rich content display with custom styling
- Mathematical expressions rendered via `flutter_math_fork`
- Images cached locally and served via `cached://` URLs
- Custom HTML style maps defined in each detail screen

### Offline Image Management
```dart
// Image caching pattern used throughout the app
final cachedImage = await publicationService.getCachedImageFile(publicationId);
```

## Key Conventions

### File Naming Patterns
- Models: Simple class names (`Publication`, `Chapter`, `SubChapter`)
- Services: Suffix with `Service` (`PublicationService`, `LocalStorageService`)  
- Screens: Suffix with `Screen` (`PublicationListScreen`, `SubChapterDetailScreen`)
- Cached files: Prefix pattern (`fullcontent_${id}.json`, `pubimg_${id}.img`)

### Error Handling
- Extensive logging with emoji prefixes for easy debugging (`💾`, `📖`, `💥`, `🔍`)
- Try-catch blocks around all async operations
- User-friendly error messages in Norwegian

### State Management
- Minimal external dependencies - uses built-in StatefulWidget patterns
- SharedPreferences for persistence
- Manual state synchronization between screens via callbacks

## Integration Points

### External Dependencies
- **Azure AD B2C**: Authentication provider with specific tenant configuration
- **Flutter HTML**: Custom styling required for mathematical content
- **Path Provider**: Cross-platform file system access
- **Connectivity Plus**: Network status monitoring

### Android-Specific Considerations
- Custom HTTP client that accepts self-signed certificates for localhost development
- URL rewriting for Android emulator (`localhost` → `10.0.2.2`)

## Common Patterns to Follow

### Service Instantiation
```dart
// Always dispose services in StatefulWidget
late final PublicationService _publicationService;

@override
void initState() {
  super.initState();
  _publicationService = PublicationService();
}

@override
void dispose() {
  _publicationService.dispose();
  super.dispose();
}
```

### Bookmark Management
```dart
// Consistent bookmark pattern across subchapter screens
Future<void> saveBookmark(SubChapter sub) async {
  final prefs = await SharedPreferences.getInstance();
  final List<SubChapter> current = await loadBookmarks();
  if (current.any((s) => s.id == sub.id)) return; // Prevent duplicates
}
```

### Network Error Handling
- Always provide offline fallback when network operations fail
- Check `LocalStorageService` for cached content before making API calls
- Display appropriate Norwegian error messages for network issues

### Background Update Checking
- **Automatic Checking**: Updates checked every 30 minutes when app is active and user is logged in
- **UpdateDate Tracking**: API's `UpdateDate` field compared against locally stored dates
- **User Notifications**: SnackBar notifications for available updates with navigation to My Page
- **Manual Checks**: Users can manually check for updates via My Page button

```dart
// Background service starts automatically when user logs in
UpdateCheckService.instance.startBackgroundChecking(context);

// Manual update check from UI
final updatesAvailable = await UpdateCheckService.instance.checkForUpdatesManually();
```

## Norwegian Language Context
- All user-facing strings are in Norwegian (Bokmål)
- Error messages and logging should maintain Norwegian context
- UI labels follow Norwegian VVS industry terminology