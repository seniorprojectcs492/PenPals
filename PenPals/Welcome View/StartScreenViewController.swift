//
//  StartScreenViewController.swift
//  PenPals
//
//  Created by Tim Van Cauwenberge on 4/24/20.
//  Copyright © 2020 SeniorProject. All rights reserved.
//

import UIKit

class StartScreenViewController: UIViewController {

    @IBOutlet weak var signUpButton: UIButton!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var versionNumLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Localization
        signUpButton.setTitle(NSLocalizedString("Sign Up", comment: ""), for: .normal)
        versionLabel.text = NSLocalizedString("Version", comment: "")
        
        //set app version
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            
            versionNumLabel.text = version
        }
        
    }

}
