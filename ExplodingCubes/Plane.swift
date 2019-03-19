import ARKit
import SceneKit

@available(iOS 11.0, *)
class Plane
{
    var planeAnchor: ARPlaneAnchor
    var planeGeometry: SCNPlane
    var node: SCNNode
    var wallGeometry: SCNPlane?
    var wallNode: SCNNode?
    var fireNode: SCNNode
    var fireSpawnTimer: Timer?
    var blockSpawnTimer: Timer?
    
    public init(_ anchor: ARPlaneAnchor)
    {
        let grid = UIImage(named: "starttexture.png")
        let planeGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        let material = SCNMaterial()
        material.diffuse.contents = grid
        planeGeometry.materials = [material]
        self.node = SCNNode(geometry: planeGeometry)
        self.node.name = "plane"
        self.node.categoryBitMask = PlaneCategoryBitmask
        
        self.planeAnchor = anchor
        self.planeGeometry = planeGeometry
        
        self.node.transform = SCNMatrix4MakeRotation(-Float.pi / 2.0, 1, 0, 0)
        self.node.position = SCNVector3(anchor.center.x, -0.002, anchor.center.z) // 2 mm below the origin of plane.
        
        // add fire emoji
        let geo = SCNPlane(width: 0.6, height: 0.6)
        geo.firstMaterial?.diffuse.contents = Plane.makeImageFromEmoji(emoji: "🔥")
        self.fireNode = SCNNode(geometry: geo)
        self.fireNode.constraints = [SCNBillboardConstraint()]
        self.fireNode.position = SCNVector3(0, 0, 0.2)
        
        self.node.addChildNode(self.fireNode)
        
        self.createPhysicsBody()
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(_ anchor: ARPlaneAnchor)
    {
        self.planeAnchor = anchor
        
        self.planeGeometry.width = CGFloat(anchor.extent.x)
        self.planeGeometry.height = CGFloat(anchor.extent.z)
        
        self.node.position = SCNVector3Make(anchor.center.x, -0.002, anchor.center.z)
        self.createPhysicsBody()
        
        // update walls
        self.wallGeometry?.width = CGFloat(anchor.extent.x)
        self.wallGeometry?.height = CGFloat(anchor.extent.z)
        self.wallNode?.position = SCNVector3(anchor.center.x + anchor.extent.x / 2, -0.002, anchor.center.z + anchor.extent.z / 2) // 2 mm below the origin of plane.
    }
    
    func startGame()
    {
        self.node.runAction(SCNAction.repeatForever(SCNAction.playAudio(SCNAudioSource(named: "lava.wav")!, waitForCompletion: true)))
        self.node.geometry?.materials[0].diffuse.contents = UIImage(named: "floortexture.jpg")
        self.fireNode.removeFromParentNode()
        
        // create walls around the playing area
        self.wallGeometry = SCNPlane(width: CGFloat(self.planeAnchor.extent.x), height: CGFloat(self.planeAnchor.extent.z))
        self.wallNode = SCNNode(geometry: self.wallGeometry)
        self.wallNode?.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        self.wallNode?.transform = SCNMatrix4MakeRotation(0, 1, 0, 0)
        // TODO FINISH!!
        
        // start spawning small fire
        self.fireSpawnTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(spawnSmallFire), userInfo: nil, repeats: true)
        
        self.blockSpawnTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true, block: { (timer: Timer) in
            self.spawnCube()
        })
        
        // TEST add smoke
        let particleSystem = SCNParticleSystem(named: "smoke", inDirectory: nil)
        let particleNode = SCNNode()
        particleNode.addParticleSystem(particleSystem!)
        self.node.addChildNode(particleNode)
    }
    
    func spawnCube()
    {
        let cube = ExplodingCube()
        let randPosition = self.getRandomPointOnPlane()
        cube.position = SCNVector3(randPosition.x, randPosition.y, 0.2)
        self.node.addChildNode(cube)
    }
    
    @objc
    func spawnSmallFire()
    {
        let geo = SCNPlane(width: 0.15, height: 0.15)
        geo.firstMaterial?.diffuse.contents = Plane.makeImageFromEmoji(emoji: "🔥")
        let smallFireNode = SCNNode(geometry: geo)
        smallFireNode.constraints = [SCNBillboardConstraint()]
        //fireNode.position = SCNVector3(self.planeAnchor.extent.x / 2, self.planeAnchor.extent.z / 2, 0.05)
        let randPosition = self.getRandomPointOnPlane()
        smallFireNode.position = SCNVector3(randPosition.x, randPosition.y, 0.05)
        self.node.addChildNode(smallFireNode)
        
        let randomDuration = self.randomDouble(min: 0.5, max: 3)
        smallFireNode.runAction(SCNAction.sequence([SCNAction.wait(duration: randomDuration), SCNAction.removeFromParentNode()]))
    }
    
    func randomFloat(min: Float, max: Float) -> Float
    {
        return (Float(arc4random()) / 0xFFFFFFFF) * (max - min) + min
    }
    
    func randomDouble(min: Double, max: Double) -> Double
    {
        return (Double(arc4random()) / 0xFFFFFFFF) * (max - min) + min
    }
    
    func getRandomPointOnPlane() -> SCNVector3
    {
        return SCNVector3(self.randomFloat(min: 0, max: self.planeAnchor.extent.x) - self.planeAnchor.extent.x / 2, self.randomFloat(min: 0, max: self.planeAnchor.extent.z) - self.planeAnchor.extent.z / 2, 0)
    }
    
    func createPhysicsBody()
    {
        let shape = SCNPhysicsShape(geometry: self.planeGeometry, options: nil)
        self.node.physicsBody = SCNPhysicsBody(type: .static, shape: shape)
        self.node.physicsBody?.isAffectedByGravity = false
        self.node.physicsBody?.categoryBitMask = PlaneCategoryBitmask
        self.node.physicsBody?.collisionBitMask = CubeCategoryBitmask
        self.node.physicsBody?.contactTestBitMask = CubeCategoryBitmask
    }
    
    static func makeImageFromEmoji(emoji: String) -> UIImage
    {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: 100, height: 100), false, 0)
        let c = UIGraphicsGetCurrentContext()
        c?.translateBy(x: 25, y: 25)
        emoji.draw(in: CGRect(origin: CGPoint.zero, size: CGSize(width: 55, height: 55)), withAttributes: [NSAttributedString.Key.font: UIFont.systemFont(ofSize: 50), NSAttributedString.Key.backgroundColor: UIColor.clear])
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!
    }
}
