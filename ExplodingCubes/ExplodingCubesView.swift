import ARKit
import Foundation
import UIKit

@available(iOS 11.0, *)
public class ExplodingCubesView: ARSCNView, ARSCNViewDelegate, SCNPhysicsContactDelegate
{
    var tracking = true
    var foundSurface = false
    var trackerNode: SCNNode?
    var planes = [ARPlaneAnchor: Plane]()
    var canShootBullet = true
    var bulletTimer: Timer?
    var didStartGame = false
    var activePlane: Plane?
    var blockSpawnTimer: Timer?
    
    var timeLeftLabel: UILabel?
    var scoreLabel: UILabel?
    var findPlaneLabel: UILabel?
    
    public override init(frame: CGRect, options: [String : Any]? = nil)
    {
        super.init(frame: frame, options: options)
        
        initWorld()
    }
    
    required public init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        initWorld()
    }
    
    func initWorld()
    {
        let scene = SCNScene()
        scene.physicsWorld.gravity = SCNVector3(x: 0, y: -0.25, z: 0)
        scene.physicsWorld.contactDelegate = self
        self.scene = scene
        self.delegate = self
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        self.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints];
        
        self.session.run(configuration)
        
        // listen for taps
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(ExplodingCubesView.viewTapped(sender: )))
        self.addGestureRecognizer(recognizer)
        
        // add labels
        self.scoreLabel = UILabel(frame: CGRect(x: self.frame.size.width - 100, y: 30, width: 100, height: 30))
        scoreLabel?.text = "Score: 3"
        scoreLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        scoreLabel?.isHidden = true
        scoreLabel?.textColor = UIColor.white
        self.addSubview(self.scoreLabel!)
        
        self.timeLeftLabel = UILabel(frame: CGRect(x: 20, y: 30, width: self.frame.size.width - 20, height: 30))
        timeLeftLabel?.text = "Time left: 30 sec."
        timeLeftLabel?.font = UIFont.boldSystemFont(ofSize: 16)
        timeLeftLabel?.isHidden = true
        timeLeftLabel?.textColor = UIColor.white
        self.addSubview(self.timeLeftLabel!)
        
        self.findPlaneLabel = UILabel(frame: CGRect(x: 0, y: 30, width: self.frame.size.width, height: 30))
        findPlaneLabel?.text = "Find a flat surface and press the 🔥"
        findPlaneLabel?.font = UIFont.boldSystemFont(ofSize: 20)
        findPlaneLabel?.textAlignment = .center
        findPlaneLabel?.textColor = UIColor.white
        self.addSubview(self.findPlaneLabel!)
    }
    
    func getUserVector() -> (SCNVector3, SCNVector3)
    {
        if let frame = self.session.currentFrame
        {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            
            return (dir, pos)
        }
        return (SCNVector3(0, 0, -1), SCNVector3(0, 0, -0.1))
    }
    
    func projectedDirection(pt: CGPoint?) -> SCNVector3
    {
        guard pt != nil else {
            return SCNVector3(0, 0, 1)
        }
        
        let farPt  = self.unprojectPoint(SCNVector3(Float(pt!.x), Float(pt!.y), 1))
        let nearPt = self.unprojectPoint(SCNVector3(Float(pt!.x), Float(pt!.y), 0))
        
        return SCNVector3((farPt.x - nearPt.x)/300, (farPt.y - nearPt.y)/300, (farPt.z - nearPt.z)/300)
    }
    
    @objc
    func viewTapped(sender: UITapGestureRecognizer)
    {
        if canShootBullet && didStartGame
        {
            let bulletsNode = Bullet()
            bulletsNode.position = (self.pointOfView?.position)!
            bulletsNode.physicsBody?.applyForce(projectedDirection(pt: sender.location(in: self)), asImpulse: true)
            self.scene.rootNode.addChildNode(bulletsNode)
            bulletsNode.runAction(SCNAction.sequence([SCNAction.playAudio(SCNAudioSource(fileNamed: "pew.wav")!, waitForCompletion: false), SCNAction.wait(duration: 3), SCNAction.removeFromParentNode()]))
            self.canShootBullet = false
            bulletTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false, block: { (timer: Timer) in
                self.canShootBullet = true
            })
        }
        
        if !self.didStartGame
        {
            // did we tap a plane?
            let hits = self.hitTest(sender.location(in: self), options: [SCNHitTestOption.categoryBitMask: PlaneCategoryBitmask])
            for hit in hits
            {
                if hit.node.name == "plane"
                {
                    // which plane did we tap?
                    for (_, plane) in self.planes
                    {
                        if plane.node == hit.node
                        {
                            self.activePlane = plane
                        }
                    }
                    
                    if let _ = self.activePlane
                    {
                        // remove other planes
                        for (_, plane) in self.planes
                        {
                            if plane.node != self.activePlane!.node
                            {
                                plane.node.removeFromParentNode()
                                plane.fireNode.removeFromParentNode()
                            }
                        }
                        
                        self.didStartGame = true
                        self.blockSpawnTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { (timer: Timer) in
                            // add cube
                            let cube = ExplodingCube()
                            let position = self.activePlane!.planeAnchor.transform
                            cube.position = SCNVector3(position.columns.3.x, position.columns.3.y + 0.8, position.columns.3.z)
                            self.scene.rootNode.addChildNode(cube)
                        })
                        hit.node.runAction(SCNAction.repeatForever(SCNAction.playAudio(SCNAudioSource(named: "lava.wav")!, waitForCompletion: true)))
                        hit.node.geometry?.materials[0].diffuse.contents = UIImage(named: "floortexture.jpg")
                        self.activePlane?.fireNode.removeFromParentNode()
                        
                        // show labels
                        self.scoreLabel?.isHidden = false
                        self.timeLeftLabel?.isHidden = false
                        self.findPlaneLabel?.isHidden = true
                    }
                }
            }
        }
        
        
//        let hits = self.hitTest(sender.location(in: self), options: [SCNHitTestOption.categoryBitMask: 4])
//        for hit in hits
//        {
//            if hit.node.name == "cube"
//            {
//                // go out with a blast
//                let particleSystem = SCNParticleSystem(named: "explosion", inDirectory: nil)
//                let particleNode = SCNNode()
//                particleNode.addParticleSystem(particleSystem!)
//
//                particleNode.position = SCNVector3Zero
//                hit.node.addChildNode(particleNode)
//
//                hit.node.parent?.runAction(SCNAction.playAudio(SCNAudioSource(fileNamed: "explosion.wav")!, waitForCompletion: false))
//                hit.node.runAction(SCNAction.sequence([SCNAction.wait(duration: 0.3), SCNAction.removeFromParentNode()]))
//            }
//        }
        
        
//        let bulletsNode = Bullet()
//        bulletsNode.position = (self.pointOfView?.position)!
//        bulletsNode.physicsBody?.applyForce(projectedDirection(pt: sender.location(in: self)), asImpulse: true)
//        self.scene.rootNode.addChildNode(bulletsNode)
//        bulletsNode.runAction(SCNAction.sequence([SCNAction.playAudio(SCNAudioSource(fileNamed: "pew.wav")!, waitForCompletion: false), SCNAction.wait(duration: 3), SCNAction.removeFromParentNode()]))
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor)
    {
        if let planeAnchor = anchor as? ARPlaneAnchor
        {
            self.addPlane(node: node, anchor: planeAnchor)
        }
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor)
    {
        if let planeAnchor = anchor as? ARPlaneAnchor
        {
            self.updatePlane(anchor: planeAnchor)
        }
    }
    
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor)
    {
        if !self.didStartGame
        {
            let plane = Plane(anchor)
            node.addChildNode(plane.node)
            node.addChildNode(plane.fireNode)
            //node.addChildNode(plane.wallNode)
            planes[anchor] = plane
        }
    }
    
    func updatePlane(anchor: ARPlaneAnchor)
    {
        if let plane = planes[anchor]
        {
            // TODO UNCOMMENT
            plane.update(anchor)
        }
    }
    
    public func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact)
    {
        if (contact.nodeA.name == "bullet" && contact.nodeB.name == "cube") || (contact.nodeA.name == "cube" && contact.nodeB.name == "bullet")
        {
            let bullet = contact.nodeA.name == "bullet" ? contact.nodeA : contact.nodeB
            let cube = contact.nodeA.name == "bullet" ? contact.nodeB : contact.nodeA
            
            bullet.removeFromParentNode()
            cube.parent?.runAction(SCNAction.playAudio(SCNAudioSource(fileNamed: "extinguish.wav")!, waitForCompletion: false))
            cube.removeFromParentNode()
            
            let particleSystem = SCNParticleSystem(named: "score", inDirectory: nil)
            let particleNode = SCNNode()
            particleNode.addParticleSystem(particleSystem!)
            particleNode.position = bullet.presentation.position
            self.scene.rootNode.addChildNode(particleNode)
        }
        else if (contact.nodeA.name == "plane" && contact.nodeB.name == "cube") || (contact.nodeA.name == "cube" && contact.nodeB.name == "plane")
        {
            let cube = contact.nodeA.name == "plane" ? (contact.nodeB as? ExplodingCube) : (contact.nodeA as? ExplodingCube)
            if !cube!.isTicking { cube?.startTicking() }
        }
    }
    
//    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval)
//    {
//        guard tracking else { return }
//        let hitTest = self.hitTest(CGPoint(x: self.frame.midX, y: self.frame.midY), types: .featurePoint)
//        guard let result = hitTest.first else { return }
//        let translation = SCNMatrix4(result.worldTransform)
//        let position = SCNVector3Make(translation.m41, translation.m42, translation.m43)
//
//        if trackerNode == nil {
//            let plane = SCNPlane(width: 0.15, height: 0.15)
//            plane.firstMaterial?.diffuse.contents = UIImage(named: "tracker.png")
//            plane.firstMaterial?.isDoubleSided = true
//            trackerNode = SCNNode(geometry: plane)
//            trackerNode?.eulerAngles.x = -.pi * 0.5
//            self.scene.rootNode.addChildNode(self.trackerNode!)
//            foundSurface = true
//        }
//        self.trackerNode?.position = position
//    }
}
