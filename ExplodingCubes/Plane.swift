import ARKit
import SceneKit

@available(iOS 11.0, *)
class Plane
{
    var planeAnchor: ARPlaneAnchor
    var planeGeometry: SCNPlane
    var node: SCNNode
    var fireNode: SCNNode
    var countdownTextNode: SCNNode?
    var fireSpawnTimer: Timer?
    var blockSpawnTimer: Timer?
    var countdownTimer: Timer?
    var countdown = 0
    
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
    }
    
    func createWall(geometry: SCNGeometry, position: SCNVector3)
    {
        let wallNode = SCNNode(geometry: geometry)
        wallNode.geometry?.firstMaterial?.diffuse.contents = UIColor.clear
        wallNode.position = position
        wallNode.name = "wall"
        
        let shape = SCNPhysicsShape(geometry: geometry, options: nil)
        wallNode.physicsBody = SCNPhysicsBody(type: .static, shape: shape)
        wallNode.physicsBody?.categoryBitMask = WallCategoryBitmask
        wallNode.physicsBody?.collisionBitMask = CubeCategoryBitmask
        wallNode.physicsBody?.contactTestBitMask = CubeCategoryBitmask
        
        self.node.addChildNode(wallNode)
    }
    
    func startGame()
    {
        self.node.runAction(SCNAction.repeatForever(SCNAction.playAudio(SCNAudioSource(named: "lava.wav")!, waitForCompletion: true)))
        self.node.geometry?.materials[0].diffuse.contents = UIImage(named: "floortexture.jpg")
        self.fireNode.removeFromParentNode()
        
        // create walls around the playing area
        var wallBox = SCNBox(width: 0.1, height: CGFloat(self.planeAnchor.extent.z), length: 0.4, chamferRadius: 0)
        self.createWall(geometry: wallBox, position: SCNVector3(self.planeAnchor.extent.x / 2 + 0.05, 0, 0.1))
        
        wallBox = SCNBox(width: 0.1, height: CGFloat(self.planeAnchor.extent.z), length: 0.4, chamferRadius: 0)
        self.createWall(geometry: wallBox, position: SCNVector3(-self.planeAnchor.extent.x / 2 - 0.05, 0, 0.1))
        
        wallBox = SCNBox(width: CGFloat(self.planeAnchor.extent.x), height: 0.1, length: 0.4, chamferRadius: 0)
        self.createWall(geometry: wallBox, position: SCNVector3(0, self.planeAnchor.extent.z / 2 + 0.05, 0.1))
        
        wallBox = SCNBox(width: CGFloat(self.planeAnchor.extent.x), height: 0.1, length: 0.4, chamferRadius: 0)
        self.createWall(geometry: wallBox, position: SCNVector3(0, -self.planeAnchor.extent.z / 2 - 0.05, 0.1))
        
        // start spawning small fire
        self.fireSpawnTimer = Timer.scheduledTimer(timeInterval: 2, target: self, selector: #selector(spawnSmallFire), userInfo: nil, repeats: true)
        
        // add the countdown text
        self.countdownTextNode = self.createTextNode(string: "3")
        self.node.addChildNode(self.countdownTextNode!)
        
        // start countdown
        self.countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (timer: Timer) in
            self.countdown += 1
            
            self.countdownTextNode?.removeFromParentNode()
            self.countdownTextNode = self.createTextNode(string: "\(3 - self.countdown)")
            self.node.addChildNode(self.countdownTextNode!)
            
            if self.countdown == 3
            {
                timer.invalidate()
                self.blockSpawnTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true, block: { (timer: Timer) in
                    self.spawnCube()
                })
                self.countdownTextNode?.removeFromParentNode()
            }
        })
        
        let particleSystem = SCNParticleSystem(named: "smoke", inDirectory: nil)
        let particleNode = SCNNode()
        particleNode.addParticleSystem(particleSystem!)
        self.node.addChildNode(particleNode)
    }
    
    func stopGame()
    {
        self.blockSpawnTimer?.invalidate()
    }
    
    func createTextNode(string: String) -> SCNNode
    {
        let text = SCNText(string: string, extrusionDepth: 0.1)
        text.font = UIFont.systemFont(ofSize: 1.0)
        text.flatness = 0.005
        text.firstMaterial?.diffuse.contents = UIColor.white
        
        let textNode = SCNNode(geometry: text)
        textNode.constraints = [SCNBillboardConstraint()]
        
        let fontSize = Float(0.2)
        textNode.scale = SCNVector3(fontSize, fontSize, fontSize)
        
        var minVec = SCNVector3Zero
        var maxVec = SCNVector3Zero
        (minVec, maxVec) =  textNode.boundingBox
        textNode.pivot = SCNMatrix4MakeTranslation(minVec.x + (maxVec.x - minVec.x) / 2, minVec.y, minVec.z + (maxVec.z - minVec.z) / 2)
        
        return textNode
    }
    
    func spawnCube()
    {
        let cube = ExplodingCube(size: CGFloat(min(self.planeAnchor.extent.x / 8, self.planeAnchor.extent.z / 8)))
        let randPosition = self.getRandomPointOnPlane(offsetX: self.planeAnchor.extent.x / 10, offsetZ: self.planeAnchor.extent.z / 10)
        cube.position = SCNVector3(randPosition.x, randPosition.y, 0.3)
        self.node.addChildNode(cube)
    }
    
    @objc
    func spawnSmallFire()
    {
        let flameSize = self.planeAnchor.extent.x / 7
        let geo = SCNPlane(width: CGFloat(flameSize), height: CGFloat(flameSize))
        geo.firstMaterial?.diffuse.contents = Plane.makeImageFromEmoji(emoji: "🔥")
        let smallFireNode = SCNNode(geometry: geo)
        smallFireNode.constraints = [SCNBillboardConstraint()]
        //fireNode.position = SCNVector3(self.planeAnchor.extent.x / 2, self.planeAnchor.extent.z / 2, 0.05)
        let randPosition = self.getRandomPointOnPlane()
        smallFireNode.position = SCNVector3(randPosition.x, randPosition.y, flameSize / 2)
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
    
    func getRandomPointOnPlane(offsetX: Float = 0, offsetZ: Float = 0) -> SCNVector3
    {
        return SCNVector3(self.randomFloat(min: 0, max: self.planeAnchor.extent.x - offsetX) - self.planeAnchor.extent.x / 2, self.randomFloat(min: 0, max: self.planeAnchor.extent.z - offsetZ) - self.planeAnchor.extent.z / 2, 0)
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
