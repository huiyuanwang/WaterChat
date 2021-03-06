//
//  MessagePasser.swift
//  WaterChat
//
//  Created by Hsueh-Hung Cheng on 3/6/15.
//  Copyright (c) 2015 Hsueh-Hung Cheng. All rights reserved.
//

import Foundation
import MultipeerConnectivity

class MessagePasser: NSObject, MCNearbyServiceBrowserDelegate, MCNearbyServiceAdvertiserDelegate, MCSessionDelegate {
    
    // for multipeer conectivity
    var browser : MCNearbyServiceBrowser!
    var advisor : MCNearbyServiceAdvertiser!
    var session : MCSession!
    var peerID: MCPeerID!
    var cb: CommunicationBuffer!
    var rm: RouteManager!
    var macPeerMapping = Dictionary<MacAddr, MCPeerID>()

    
    // Singlton Pattern
    class var getInstance: MessagePasser {
        struct Static {
            static var instance: MessagePasser?
        }
        
        if Static.instance == nil {
            Static.instance = MessagePasser()
        }
        return Static.instance!
    }
    
    // constructor is private so outsider has to call getInstance()
    private override init() {
        // I don't know what is super
        super.init();
        
        // display name is the mac addr in UInt64
        self.peerID = MCPeerID(displayName: UIDevice.currentDevice().name)
        self.session = MCSession(peer: peerID)
        self.session.delegate = self
        self.cb = CommunicationBuffer(mp: self)
        self.rm = RouteManager(addr: 1, mp: self)
        
        // create the browser viewcontroller with a unique service name
        self.browser = MCNearbyServiceBrowser(peer: self.peerID, serviceType: Config.serviceType)
        
        self.browser.delegate = self;
        
        self.advisor = MCNearbyServiceAdvertiser(peer: self.peerID, discoveryInfo:nil, serviceType: Config.serviceType)
        self.advisor.delegate = self
        
        Logger.log("Initialize MessagePasser with name = \(UIDevice.currentDevice().name)")
        
        // Begins advertising the service provided by a local peer
        self.advisor.startAdvertisingPeer()
        
        // Starts browsing for peers
        self.browser.startBrowsingForPeers()
        
        Logger.log("Started advertising and browsing")
    }
    
    // The following two methods are required for MCNearbyServiceBrowserDelegate
    
    func browser(browser: MCNearbyServiceBrowser!,
        foundPeer: MCPeerID!,
        withDiscoveryInfo info: [NSObject : AnyObject]!) {
            Logger.log("found a new peer \(foundPeer.displayName)")
            // send the invitation
            self.session.connectPeer(foundPeer,
                withNearbyConnectionData: nil)
            self.browser.invitePeer(foundPeer, toSession: self.session, withContext: nil, timeout: NSTimeInterval(300))
    }
    
    func browser(browser: MCNearbyServiceBrowser!,
        lostPeer: MCPeerID!) {
            Logger.log("lost a new peer \(lostPeer.displayName)")
    }
    
    func advertiser(advertiser: MCNearbyServiceAdvertiser!,
        didReceiveInvitationFromPeer peerID: MCPeerID!,
        withContext context: NSData!,
        invitationHandler: ((Bool,
        MCSession!) -> Void)!) {
            
            Logger.log("Received an invitation from \(peerID.displayName)")
            invitationHandler(true, self.session)
    }

    
    
    // Called when a peer sends an NSData to us
    func session(session: MCSession!, didReceiveData data: NSData!,
        fromPeer peerID: MCPeerID!)  {
            Logger.log("Got data from \(peerID)")
            
            // This needs to run on the main queue
            dispatch_async(dispatch_get_main_queue()) {
                
                var message = Message.messageFactory(data)
                var fromAddr = Util.convertDisplayNameToMacAddr(peerID.displayName)
                
                
                switch message.type {
                case MessageType.RREQ:
                    self.rm.reveiveRouteRequest(fromAddr, message: message as RouteRequest)
                    break
                case MessageType.RREP:
                    break
                case MessageType.RERR:
                    break
                case MessageType.UNKNOWN:
                    self.cb.addToIncomingBuffer(message)
                    break
                default:
                    Logger.error("Unknown message")
                }
            }
    }
    
    // The following methods do nothing, but the MCSessionDelegate protocol
    // requires that we implement them.
    func session(session: MCSession!,
        didStartReceivingResourceWithName resourceName: String!,
        fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!)  {
            
            // Called when a peer starts sending a file to us
    }
    
    func session(session: MCSession!,
        didFinishReceivingResourceWithName resourceName: String!,
        fromPeer peerID: MCPeerID!,
        atURL localURL: NSURL!, withError error: NSError!)  {
            // Called when a file has finished transferring from another peer
    }
    
    func session(session: MCSession!, didReceiveStream stream: NSInputStream!,
        withName streamName: String!, fromPeer peerID: MCPeerID!)  {
            // Called when a peer establishes a stream with us
    }
    
    func session(session: MCSession!, peer peerID: MCPeerID!,
        didChangeState state: MCSessionState)  {
            // Called when a connected peer changes state (for example, goes offline)
    }
    
    func send(dest: MacAddr, message: Message) {
        //self.cb.send(dest, data: message.serialize())
    }
    
    func send(dest: MCPeerID, message: Message) {
        var rawMessage = RawMessage(dest: dest, data: message.serialize())
        self.cb.addToOutgoingBuffer(rawMessage)
    }
    
    func broadcast(message: Message) {
        dispatch_async(dispatch_get_main_queue()) {
            self.cb.broadcast(message.serialize())
        }
    }
    
    // called by the application
    //func receive() -> Message {
    //}
    
}
