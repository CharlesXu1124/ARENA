//
//  ViewController.swift
//  ARENA
//
//  Created by Zheyuan Xu on 12/12/20.
//

import UIKit
import RealityKit
import ARKit
import CoreBluetooth
import CoreML

class ViewController: UIViewController, CBCentralManagerDelegate, ARSessionDelegate {
    let IMUUUID = CBUUID(string: "917649A0-D98E-11E5-9EEC-0002A5D5C51B")
    let IMUx = CBUUID(string: "917649A0-D98E-11E5-9EEC-0002A5D5C51B")
    let IMUy = CBUUID(string: "917649A0-D98E-11E5-9EEC-0002A5D5C51C")
    let IMUz = CBUUID(string: "917649A0-D98E-11E5-9EEC-0002A5D5C51D")
    
    var accel_x: Float!
    var accel_y: Float!
    var accel_z: Float!
    
    var semaphoreX: Bool!
    var semaphoreY: Bool!
    
    
    var IMUPeripheral: CBPeripheral!
    
    var centralManager: CBCentralManager!
    @IBOutlet var arView: ARView!
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .unknown:
          print("central.state is .unknown")
        case .resetting:
          print("central.state is .resetting")
        case .unsupported:
          print("central.state is .unsupported")
        case .unauthorized:
          print("central.state is .unauthorized")
        case .poweredOff:
          print("central.state is .poweredOff")
        case .poweredOn:
            print("central.state is .poweredOn")
            centralManager.scanForPeripherals(withServices: [IMUUUID])
        @unknown default:
            fatalError()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected!")
        IMUPeripheral.discoverServices([IMUUUID])
        
    }
    
    func setupARView() {
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        arView.session.run(configuration)
    }
    
    @objc
    func handleTap(recognizer: UITapGestureRecognizer) {
        SceneAnchor.notifications.startLanding.post()
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        print(peripheral)
        IMUPeripheral = peripheral
        IMUPeripheral.delegate = self
        centralManager.stopScan()
        centralManager.connect(IMUPeripheral)
    }
    
    var SceneAnchor: ARENA.Scene!
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        arView.session.delegate = self
        setupARView()
        arView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:))))
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        semaphoreX = false
        semaphoreY = false
        
        accel_x = 0
        accel_y = 0
        accel_z = 0
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        
        // Load the "Box" scene from the "Experience" Reality File
        SceneAnchor = try! ARENA.loadScene()
        
        // Add the box anchor to the scene
        arView.scene.anchors.append(SceneAnchor)
    }
    
    func bytesToFloat(bytes b: [UInt8]) -> Float {
        let littleEndianValue = b.withUnsafeBufferPointer {
            $0.baseAddress!.withMemoryRebound(to: UInt32.self, capacity: 1) { $0.pointee }
        }
        let bitPattern = UInt32(littleEndian: littleEndianValue)
        return Float(bitPattern: bitPattern)
    }
}

extension ViewController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
      guard let characteristics = service.characteristics else { return }
      for characteristic in characteristics {
        print(characteristic)
        peripheral.readValue(for: characteristic)
        peripheral.setNotifyValue(true, for: characteristic)
      }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
      switch characteristic.uuid {
      case IMUx:
          let rawX = [UInt8](characteristic.value!)
          accel_x = bytesToFloat(bytes: rawX)
          if (accel_x < -0.7) && (!semaphoreX) {
            semaphoreX = true
            SceneAnchor.notifications.forward.post()
            DispatchQueue.main.async {
                _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) {_ in
                    // release semaphore for Y axis after 0.5 seconds
                    self.semaphoreX = false
                }
            }
          }
          if (accel_x > 0.7) && (!semaphoreX) {
            semaphoreX = true
            SceneAnchor.notifications.backward.post()
            DispatchQueue.main.async {
                _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) {_ in
                    // release semaphore for Y axis after 0.5 seconds
                    self.semaphoreX = false
                }
            }
          }
          //print(accel_x ?? "no value for x-axis acceleration")
      case IMUy:
          let rawY = [UInt8](characteristic.value!)
          accel_y = bytesToFloat(bytes: rawY)
          print(accel_y ?? "no value for y-axis acceleration")
          if (accel_y < -0.7) && (!semaphoreY) {
            semaphoreY = true
            SceneAnchor.notifications.left.post()
            DispatchQueue.main.async {
                _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) {_ in
                    // release semaphore for Y axis after 0.5 seconds
                    self.semaphoreY = false
                }
            }
          }
          if (accel_y > 0.7) && (!semaphoreY){
            semaphoreY = true
            SceneAnchor.notifications.right.post()
            DispatchQueue.main.async {
                _ = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) {_ in
                    // release semaphore for Y axis after 0.5 seconds
                    self.semaphoreY = false
                }
            }
          }
      case IMUz:
          let rawZ = [UInt8](characteristic.value!)
          accel_z = bytesToFloat(bytes: rawZ)
          //print(accel_z ?? "no value for y-axis acceleration")
      default:
          print("Unhandled Characteristic UUID: \(characteristic.uuid)")
      }
    }
}
