import ProxyRule

nonisolated(unsafe)
let nintendo = RuleProvider(
  name: "Nintendo", description: "Nintendo services.",
  collections: [
    .init(
      name: "Nintendo", description: "",
      rules: [
        .init(.domainSuffix, [
          "nintendo.com", "nintendo.net"
        ])
      ], recommendedPolicy: .select)
  ])

nonisolated(unsafe)
let privateTracker = RuleProvider(
  name: "Private Tracker", description: "Private trackers and websites.",
  collections: [
    .init(
      name: "MTeam", description: "",
      rules: [
        .init(.domainSuffix, [
          "m-team.cc"
        ])
      ], recommendedPolicy: .direct),
    .init(
      name: "GayTorrent", description: "",
      rules: [
        .init(.domainSuffix, [
          "gay-torrents.org"
        ])
      ], recommendedPolicy: .direct),
    .init(
      name: "Rarbg", description: "",
      rules: [
        .init(.domainSuffix, [
          "torrentapi.org"
        ])
      ], recommendedPolicy: .select),
    .init(
      name: "TTG", description: "totheglory",
      rules: [
        .init(.domainSuffix, [
          "totheglory.im"
        ])
      ], recommendedPolicy: .select),

  ])

/*
 One Drive
 live.com

 */

nonisolated(unsafe)
let lan = RuleProvider(
  name: "LAN", description: "Rules for local area network.",
  collections: [
    .init(
      name: "CLAN",
      description: "Big C**** LAN.",
      rules: [
        .init(.geoip, ["CN"])
      ], recommendedPolicy: .direct),
    .init(
      name: "LAN", description: "Normal LAN addresses.",
      rules: [
        .init(.ipCIDR,
              ["10.0.0.0/8",
               "100.64.0.0/10",
               "127.0.0.0/8",
               "172.16.0.0/12",
               "192.168.0.0/16",
              ]),
        .init(.ipCIDR6, "fe80::/10"),
      ], recommendedPolicy: .direct)
  ])
