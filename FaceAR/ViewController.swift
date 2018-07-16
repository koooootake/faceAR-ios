//
//  ViewController.swift
//  FaceAR
//
//  Created by Rina Kotake on 2017/12/04.
//  Copyright © 2017年 Rina Kotake. All rights reserved.
//

import UIKit
import ARKit
import SceneKit

class ViewController: UIViewController, ARSessionDelegate {

    @IBOutlet weak var sceneView: ARSCNView!

    var session: ARSession {
        return sceneView.session
    }
    
    let contentUpdater = VirtualContentUpdater()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = contentUpdater
        sceneView.session.delegate = self
        //シーンの照明を更新するかどうか falseにするとマスクが真っ黒になる
        sceneView.automaticallyUpdatesLighting = true
        
        contentUpdater.virtualFaceNode = createFaceNode()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true //自動光調節をOFF
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause() //セッション停止
    }
    
    //マスクを生成
    public func createFaceNode() -> VirtualFaceNode? {
        guard
            let device = sceneView.device,
            let geometry = ARSCNFaceGeometry(device : device) else {
            return nil
        }
        
        return Mask(geometry: geometry)
    }
    
    //セッション開始
    func startSession() {
        print("STARTING A NEW SESSION")
        guard ARFaceTrackingConfiguration.isSupported else { return } //ARFaceTrackingをサポートしているか
        let configuration = ARFaceTrackingConfiguration() //顔の追跡を実行するための設定
        //オブジェクトにシーンのライティングを提供するか falseにするとマスクが真っ黒になる
        configuration.isLightEstimationEnabled = true
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    //MARK: - ARSessionDelegat
    //エラーの時
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        print("SESSION ERROR")
    }
    //中断した時
    func sessionWasInterrupted(_ session: ARSession) {
        print("SESSION INTERRUPTED")
    }
    //中断再開した時
    func sessionInterruptionEnded(_ session: ARSession) {
        DispatchQueue.main.async {
            self.startSession() //セッション再開
        }
    }
}

protocol VirtualFaceContent {
    func update(withFaceAnchor: ARFaceAnchor)
}

typealias VirtualFaceNode = VirtualFaceContent & SCNNode

class VirtualContentUpdater: NSObject, ARSCNViewDelegate {
    
    //追加 or 更新用
    var virtualFaceNode: VirtualFaceNode? {
        didSet {
            setupFaceNodeContent()
        }
    }
    //セッションを再起動する必要がないように保持用
    private var faceNode: SCNNode?
    
    private let serialQueue = DispatchQueue(label: "com.example.serial-queue")
    
    //顔コンテントのセットアップ
    private func setupFaceNodeContent() {
        guard let faceNode = faceNode else { return }
        
        //全ての子ノードを消去
        for child in faceNode.childNodes {
            child.removeFromParentNode()
        }
        //新しいcontentを追加
        if let content = virtualFaceNode {
            faceNode.addChildNode(content)
        }
    }
    
    //MARK: - ARSCNViewDelegate
    //新しいARアンカーが設置された時に呼び出される
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        faceNode = node
        serialQueue.async {
            self.setupFaceNodeContent()
        }
    }
    
    //ARアンカーが更新された時に呼び出される
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        virtualFaceNode?.update(withFaceAnchor: faceAnchor) //マスクをアップデートする
    }
}

class Mask: SCNNode, VirtualFaceContent {

    init(geometry: ARSCNFaceGeometry) {
        let material = geometry.firstMaterial//初期化
        //material?.diffuse.contents = #imageLiteral(resourceName: "girl02_angry.png")
        material?.diffuse.contents = UIColor.gray //マスクの色
        material?.lightingModel = .physicallyBased //オブジェクトの照明のモデル
        
        super.init()
        self.geometry = geometry
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("\(#function) has not been implemented")
    }
    
    //ARアンカーがアップデートされた時に呼ぶ
    func update(withFaceAnchor anchor: ARFaceAnchor) {
        guard let faceGeometry = geometry as? ARSCNFaceGeometry else { return }
        faceGeometry.update(from: anchor.geometry)
    }
}

