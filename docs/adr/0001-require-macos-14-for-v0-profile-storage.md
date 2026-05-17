# Require macOS 14 for V0 profile storage

V0 requires macOS 14 so `tweb` can model named persistent profiles with WebKit's UUID-backed persistent website data stores. Supporting older macOS versions would force weaker profile isolation, cookie export/import workarounds, or a different browser storage model before the agent-browser session loop has been proven.
