import ARKit
import SceneKit

@available(iOS 11.0, *)
class Plane
{
    var planeAnchor: ARPlaneAnchor
    var planeGeometry: SCNPlane
    var node: SCNNode
    var wallGeometry: SCNPlane
    var wallNode: SCNNode
    var fireNode: SCNNode
    
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
        
        self.wallGeometry = SCNPlane(width: CGFloat(anchor.extent.x), height: CGFloat(anchor.extent.z))
        self.wallNode = SCNNode(geometry: self.wallGeometry)
        self.wallNode.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        self.wallNode.transform = SCNMatrix4MakeRotation(0, 1, 0, 0)
        
        // add fire emoji
        let geo = SCNPlane(width: 0.6, height: 0.6)
        geo.firstMaterial?.diffuse.contents = Plane.makeImageFromEmoji(emoji: "🔥")
        self.fireNode = SCNNode(geometry: geo)
        self.fireNode.constraints = [SCNBillboardConstraint()]
        self.fireNode.position = SCNVector3(0, 0.2, 0)
        
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
        
        self.updateWalls(anchor)
    }
    
    func updateWalls(_ anchor: ARPlaneAnchor)
    {
        self.wallGeometry.width = CGFloat(anchor.extent.x)
        self.wallGeometry.height = CGFloat(anchor.extent.z)
        
        self.wallNode.position = SCNVector3(anchor.center.x + anchor.extent.x / 2, -0.002, anchor.center.z + anchor.extent.z / 2) // 2 mm below the origin of plane.
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
