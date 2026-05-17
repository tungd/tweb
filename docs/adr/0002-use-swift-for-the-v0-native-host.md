# Use Swift for the V0 native host

V0 uses Swift for the native host because the core product risk is WebKit integration: `WKWebView`, `WKUIDelegate`, `WKWebsiteDataStore`, window visibility, and the macOS event loop. OCaml/camlkit remains a possible later layer for protocol or core logic, but using it in the V0 browser host would add bridge complexity before the agent-browser session loop has been proven.
