import ProxyRule

fileprivate let appleICloud = RuleCollection(
  name: "iCloud", description: "Apple's iCloud service.",
  rules: [
    .init(.domainSuffix, [
      "icloud.com",
      "icloud-content.com"
    ])
  ], recommendedPolicy: .direct)

fileprivate let appleDeveloper = RuleCollection(
  name: "Apple Developer", description: "Apple developer site.",
  rules: [
    .init(.domain, [
      "devimages-cdn.apple.com",
      "developer.apple.com",
      "devstreaming-cdn.apple.com",
      "appleworldwidedeveloper.hb-api.omtrdc.net",
      "appleworldwidedeveloper.sc.omtrdc.net"
    ])
  ], recommendedPolicy: .select)

fileprivate let appleSoftware = RuleCollection(
  name: "Software Updates", description: "Software updates.",
  rules: [
    .init(.domain, [
      "gg.apple.com",
      "gnf-mdn.apple.com",
      "gnf-mr.apple.com", "gs.apple.com", "ig.apple.com", "ns.itunes.apple.com",
      "swdownload.apple.com", "swpost.apple.com", "xp.apple.com"
    ])
  ], recommendedPolicy: .select)



fileprivate let appleMusic = RuleCollection(
  name: "Apple Music", description: "App Music.",
  rules: [
    .init(.domain, [
      "audio.itunes.apple.com",
      "streamingaudio.itunes.apple.com",
      "aod.itunes.apple.com",
    ])
  ], recommendedPolicy: .select)
// mzstatic.com


fileprivate let appleMap = RuleCollection(
  name: "AppMap", description: "Apple Location/Map Service.",
  rules: [
    .init(.domain, [
      "iosapps.itunes.apple.com", "osxapps.itunes.apple.com",
      "ppq.apple.com",
    ]),
    .init(.domainSuffix, [
      "ls.apple.com",
      "gs-loc.apple.com"
    ])
  ], recommendedPolicy: .select)


fileprivate let appStore = RuleCollection(
  name: "AppStore", description: "App Store.",
  rules: [
    .init(.domain, [
      "iosapps.itunes.apple.com", "osxapps.itunes.apple.com",
      "ppq.apple.com",
    ]),
    .init(.domainSuffix, [
      "itunes.apple.com", "apps.apple.com",
      //          "mzstatic.com"
    ])
  ], recommendedPolicy: .select)


fileprivate let contentCaching = RuleCollection(
  name: "ContentCaching", description: "",
  rules: [
    .init(.domain, [
      "lcdn-registration.apple.com",
      "suconfig.apple.com"
    ]),
  ], recommendedPolicy: .direct)


fileprivate let blockedServices = RuleCollection(
  name: "Blocked", description: "Blocked apple services.",
  rules: [
    .init(.domainSuffix, [
      "blobstore.apple.com",
      "bookkeeper.itunes.apple.com",
      "hls.itunes.apple.com",
      "books.itunes.apple.com",
      "mvod.itunes.apple.com",
      "init.itunes.apple.com",
      "play.itunes.apple.com",
      "ld-4.itunes.apple.com",
      "se2.itunes.apple.com",
      "client-api.itunes.apple.com",
      "p43-buy.itunes.apple.com",
      "itunesu.itunes.apple.com"
    ]),
    .init(.domain, "music.apple.com")
  ], recommendedPolicy: .select)


fileprivate let certificateValidation = RuleCollection(
  name: "Certificate validation", description: "Apple devices must be able to connect to the following hosts to validate digital certificates used by the hosts listed above.",
  rules: [
    .init(.domain, [
      "crl.apple.com",
      "crl.entrust.net",
      "crl3.digicert.com",
      "crl4.digicert.com",
      "ocsp.apple.com",
      "ocsp.digicert.com",
      "ocsp.entrust.net",
      "ocsp.verisign.net"
    ]),
  ], recommendedPolicy: .select)

fileprivate let allAppleRoutes = RuleCollection(
  name: "Route", description: "The entire 17.0.0.0/8 address block is assigned to Apple.",
  rules: [
    .init(.ipCIDR, [
      "17.0.0.0/8",
    ]),
    .init(.domainSuffix, "apple.com")
  ], recommendedPolicy: .select)

let apple = RuleProvider(
  name: "Apple", description: "Apple services.",
  collections: [
    appleICloud,
    appleDeveloper,
    contentCaching,
    certificateValidation,
    allAppleRoutes
  ])
