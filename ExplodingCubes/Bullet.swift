import SceneKit
import UIKit

class Bullet: SCNNode
{
    override init ()
    {
        super.init()
        let sphere = SCNSphere(radius: 0.025)
        sphere.firstMaterial?.diffuse.contents = UIImage(named: "water.jpg")
        self.geometry = sphere
        let shape = SCNPhysicsShape(geometry: sphere, options: nil)
        self.name = "bullet"
        self.physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
        self.physicsBody?.isAffectedByGravity = false
        self.physicsBody?.categoryBitMask = BulletCategoryBitmask
        self.physicsBody?.collisionBitMask = CubeCategoryBitmask
        self.physicsBody?.contactTestBitMask = CubeCategoryBitmask
    }
    
    required init?(coder aDecoder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }
}
