//
//  RegistrationViewController.swift
//  Open House
//
//  Created by Arjun Chib on 11/9/16.
//  Copyright © 2016 Profectus. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON


// The UI elements and functionality of the user registration page
class RegistrationViewController: UserViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        titleLabel.text = "Registration"
        button.setTitle("Sign Up", for: .normal)
        switchScreen.setTitle("Already have an account?", for: .normal)
//      skip.setTitle("Skip registration", for: .normal)

        button.addTarget(self, action: #selector(RegistrationViewController.handleRegistration), for: .touchUpInside)
    }

    func handleRegistration() {
        if !isValidEmail(emailString: email.text!) {
            alert(title: "Registration Failed", message: "Invalid email.")
        } else if !isValidPassword(passwordString: password.text!) {
            alert(title: "Registration Failed", message: "Password must be between 8 and 32 characters.")
        } else {
            let parameters: Parameters = ["email": email.text!, "password": password.text!]
            Alamofire.request(Networking.baseURL + "/register", method: .post, parameters: parameters, encoding: JSONEncoding.default)
                .responseString { response in
                    if (response.error != nil) {
                        self.alert(title: "Registration Failed", message: (response.error?.localizedDescription)!)
                        return
                    }
                    let success = validate(statusCode: (response.response?.statusCode)!)
                    if success {
                        let defaults = UserDefaults.standard
                        defaults.setValue(self.email.text!, forKey: defaultsKeys.email)
                        defaults.setValue(self.password.text!, forKey: defaultsKeys.password)
                        defaults.synchronize()
                        self.navigationController?.view.layer.removeAllAnimations()
                        self.navigationController?.dismiss(animated: true, completion: {
                            let appDelegate  = UIApplication.shared.delegate as! AppDelegate
                            let rootViewController = appDelegate.window!.rootViewController as! RootViewController
                            let settingsVC = UINavigationController(rootViewController: SettingsViewController())
                            settingsVC.pushViewController(DreamHouseViewController(), animated: false)
                            rootViewController.present(settingsVC, animated: true, completion: {
                                //
                            })
                        })
                        let json = JSON(response.data!)
                        Networking.token = json["token"].stringValue
                        MyHouses.shared.syncHouses(completion: { success in
                            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "reloadHouses")))
                        })
                    } else {
                        self.alert(title: "Registration Failed", message: response.result.value!)
                    }
            }
        }
    }

    override func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        _ = super.textFieldShouldReturn(textField)
        handleRegistration()
        return false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
