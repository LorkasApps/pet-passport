package de.lorkas_apps.pet_passport

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity is required by local_auth so the biometric
// dialog can attach to a FragmentManager. FlutterActivity does not
// provide one.
class MainActivity : FlutterFragmentActivity()
