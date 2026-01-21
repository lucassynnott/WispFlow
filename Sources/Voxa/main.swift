import AppKit

// Create the application instance
let app = NSApplication.shared

// Start as regular app for onboarding to work properly
// Will switch to .accessory mode after onboarding completes
// This ensures permission dialogs are attributed correctly to Voxa
app.setActivationPolicy(.regular)

// Create and set the delegate
let delegate = AppDelegate()
app.delegate = delegate

// Run the application
app.run()
