//
//  SystemProxy.swift
//  ProxyLib
//
//  Created by Kojirou on 2018/5/13.
//

import Foundation

#if os(macOS)
    import SystemConfiguration

    let authFlags: AuthorizationFlags = [.extendRights, .interactionAllowed, .preAuthorize]

    public func setSystemSocks5Proxy(port: Int) {
        var authRef: AuthorizationRef?
        if AuthorizationCreate(nil, nil, authFlags, &authRef) == noErr,
            authRef != nil,
            let prefRef = SCPreferencesCreateWithAuthorization(nil, "ProxyServer" as CFString, nil, authRef),
            let sets = SCPreferencesGetValue(prefRef, kSCPrefNetworkServices) as? NSDictionary {
            for key in sets.allKeys {
                let dict = sets.object(forKey: key) as? NSDictionary
                let hardware = ((dict?["Interface"]) as? NSDictionary)?["Hardware"] as? String
                if hardware == "AirPort" || hardware == "Ethernet" {
                    let proxySettings = NSMutableDictionary()
                    proxySettings[kCFNetworkProxiesSOCKSProxy] = "127.0.0.1"
                    proxySettings[kCFNetworkProxiesSOCKSEnable] = 1
                    proxySettings[kCFNetworkProxiesSOCKSPort] = port
                    proxySettings[kCFNetworkProxiesExceptionsList] = [
                        "127.0.0.1",
                        "192.168.0.0/16",
                        "10.0.0.0/8",
                        "172.16.0.0/12",
                        "100.64.0.0/10",
                        "localhost",
                        "*.local",
                        "e.crashlytics.com",
                        "captive.apple.com",
                        "128:0:0:0/1",
                        "::ffff:0:0:0:0/1",
                        "::ffff:",
                    ]
                    let path = "/\(kSCPrefNetworkServices)/\(key)/\(kSCEntNetProxies)" as NSString
                    SCPreferencesPathSetValue(prefRef, path, proxySettings)
                }
            }

            SCPreferencesCommitChanges(prefRef)
            SCPreferencesApplyChanges(prefRef)
        }

        AuthorizationFree(authRef!, [])
    }
#endif
