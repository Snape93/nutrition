# Account Settings Testing Documentation

## Overview
This document outlines the comprehensive testing strategy for the Account Settings screen in the Nutrition Flutter app. The testing covers both Flutter widget tests and backend API integration tests.

## Test Structure

### 1. Flutter Widget Tests (`account_settings_test.dart`)

#### Test Categories:

**A. Basic UI Tests**
- Loading state display
- App bar functionality
- Section headers and icons
- Card layouts and styling
- Gender-based theming

**B. Form Validation Tests**
- Email validation (format checking)
- Password validation (length requirements)
- Password confirmation matching
- Required field validation
- Form submission prevention with invalid data

**C. User Interaction Tests**
- Text field input and editing
- Button interactions
- Switch toggles for notifications
- Dialog displays (delete confirmation, export data)
- Navigation and scrolling

**D. Error Handling Tests**
- Network failure scenarios
- API error responses
- Loading state management
- Form reset functionality

**E. Integration Tests**
- Complete user flows
- Cross-component interactions
- State management
- Data persistence

### 2. Backend API Tests (`test_account_settings_api.py`)

#### Test Categories:

**A. Authentication Tests**
- User registration
- Login with credentials
- Token-based authentication
- Session management

**B. Profile Management Tests**
- Get user profile data
- Update user information
- Data validation
- Error handling

**C. Email Management Tests**
- Change email address
- Email format validation
- Duplicate email handling
- Success/failure responses

**D. Password Management Tests**
- Change password functionality
- Current password verification
- New password validation
- Security requirements

**E. Account Deletion Tests**
- Account deletion process
- Data cleanup
- Authentication invalidation
- Confirmation workflows

## Test Files

### Flutter Tests
- `test/account_settings_test.dart` - Main widget tests
- `test/account_settings_test.mocks.dart` - Mock objects for testing
- `test/run_account_settings_tests.dart` - Test runner script

### Backend Tests
- `test_account_settings_api.py` - API integration tests

## Running the Tests

### Flutter Widget Tests
```bash
cd nutrition_flutter
flutter test test/account_settings_test.dart
```

### Backend API Tests
```bash
# Make sure Flask app is running
python app.py

# In another terminal, run the API tests
python test_account_settings_api.py
```

### Run All Tests
```bash
# Run Flutter tests
flutter test test/account_settings_test.dart

# Run API tests (in separate terminal)
python test_account_settings_api.py
```

## Test Coverage

### UI Components Tested
- ✅ Email Settings Section
- ✅ Password Settings Section  
- ✅ Notification Settings
- ✅ Privacy & Data Settings
- ✅ Danger Zone (Delete Account)
- ✅ Loading States
- ✅ Error Messages
- ✅ Success Messages
- ✅ Form Validation
- ✅ Dialog Boxes

### API Endpoints Tested
- ✅ POST /register
- ✅ POST /login
- ✅ GET /user/{username}
- ✅ PUT /user/{username}/email
- ✅ PUT /user/{username}/password
- ✅ DELETE /user/{username}

### User Flows Tested
- ✅ Complete email change flow
- ✅ Complete password change flow
- ✅ Notification settings management
- ✅ Data export functionality
- ✅ Account deletion process
- ✅ Error recovery scenarios

## Test Scenarios

### Valid Scenarios
1. **Email Change**: Valid email format → Success
2. **Password Change**: Valid current + new passwords → Success
3. **Notification Toggle**: User interaction → State change
4. **Data Export**: User request → Data compilation
5. **Account Deletion**: Confirmation → Account removal

### Invalid Scenarios
1. **Invalid Email**: Wrong format → Validation error
2. **Short Password**: Less than 6 characters → Validation error
3. **Mismatched Passwords**: Different confirmation → Validation error
4. **Wrong Current Password**: Incorrect current password → Authentication error
5. **Network Failure**: API unavailable → Error message

### Edge Cases
1. **Empty Fields**: Required field validation
2. **Special Characters**: Email and password handling
3. **Long Inputs**: Maximum length validation
4. **Concurrent Operations**: Multiple simultaneous requests
5. **Session Expiry**: Token expiration handling

## Mock Objects

### Flutter Mocks
- `MockClient` - HTTP client for API calls
- `MockUserDatabase` - Local database operations
- `HttpOverrides` - Network request blocking

### Test Data
- Test user credentials
- Sample email addresses
- Password test cases
- API response mocks

## Performance Testing

### Load Testing
- Multiple simultaneous users
- Large data export operations
- Database query performance
- API response times

### Memory Testing
- Widget disposal
- Controller cleanup
- Memory leaks detection
- Resource management

## Security Testing

### Authentication
- Token validation
- Session management
- Password security
- Data encryption

### Authorization
- User permission checks
- Data access control
- API endpoint security
- Input sanitization

## Continuous Integration

### Automated Testing
- GitHub Actions integration
- Test result reporting
- Coverage metrics
- Performance benchmarks

### Quality Gates
- Minimum test coverage (80%)
- No critical test failures
- Performance thresholds
- Security compliance

## Troubleshooting

### Common Issues
1. **Network Timeouts**: Check API server status
2. **Test Failures**: Verify mock configurations
3. **Flutter Tests**: Ensure proper widget setup
4. **API Tests**: Confirm database connectivity

### Debug Commands
```bash
# Flutter test with verbose output
flutter test test/account_settings_test.dart --verbose

# API test with debug mode
python test_account_settings_api.py --debug

# Check test coverage
flutter test --coverage
```

## Future Enhancements

### Planned Tests
- [ ] Accessibility testing
- [ ] Internationalization testing
- [ ] Offline functionality testing
- [ ] Performance benchmarking
- [ ] Security penetration testing

### Test Improvements
- [ ] Automated test data generation
- [ ] Visual regression testing
- [ ] Cross-platform testing
- [ ] User acceptance testing
- [ ] Load testing automation

## Conclusion

This comprehensive testing strategy ensures the Account Settings functionality is robust, secure, and user-friendly. The combination of Flutter widget tests and backend API tests provides complete coverage of the feature set, from UI interactions to data persistence.

Regular test execution and maintenance will help maintain code quality and prevent regressions as the application evolves.

