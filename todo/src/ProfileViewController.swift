//
//  ProfileViewController.swift
//  todo
//
//  Created by mac on 3/1/16.
//  Copyright © 2016 cs378. All rights reserved.
//

import UIKit

class ProfileViewController: UIViewController, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    // UI Attributes
    @IBOutlet weak var photo: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var majorLabel: UILabel!
    @IBOutlet weak var graduationLabel: UILabel!
    @IBOutlet weak var emailButton: UIButton!
    @IBOutlet weak var numDotsLabel: UILabel!
    @IBOutlet weak var coursesLabel: UILabel!
    @IBOutlet weak var rightBarButton: UIBarButtonItem!
    @IBOutlet weak var leftBarButton: UIBarButtonItem!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var majorTextField: UITextField!
    @IBOutlet weak var graduationTextField: UITextField!
    @IBOutlet weak var basicInfoView: UIView!
    @IBOutlet weak var changePhotoButton: UIButton!
    private let imagePicker = UIImagePickerController()
    
    // Class variables
    var username:String = ""
    var isOwnProfile:Bool = true
    private var name:String = ""
    private var major:String = ""
    private var graduation:String = ""
    private var numDots:Int = 0
    private var isEditing:Bool = false
    private var newPhotoString:String? = nil
    private var coursesCopy:([String],[String]){
        var coursesKeysCopy = [String]()
        var coursesValuesCopy = [String]()
        
        dispatch_sync(taskQueue) {
            for key in (user["courses"] as! [String: String]).keys {
                coursesKeysCopy.append(key)
            }
            for value in (user["courses"] as! [String: String]).values{
                coursesValuesCopy.append(value)
            }
            
        }
        return (coursesKeysCopy,coursesValuesCopy)
    }
    
    @IBOutlet weak var CoursesTableView: UITableView!
    override func viewDidLoad() {
        super.viewDidLoad()
        self.imagePicker.delegate = self
        self.CoursesTableView.delegate = self
        self.CoursesTableView.dataSource = self
        self.CoursesTableView.registerClass(UITableViewCell.self, forCellReuseIdentifier: "courseCell")
        
        self.loadData()
        self.hideEditing()
        self.displayUserPhoto()
        // self.displayUserData(true)
        self.adjustButtonFunctionality()
        
        // Format profile photo to be circular
        self.photo.layer.cornerRadius = self.photo.frame.size.width / 2
        self.photo.clipsToBounds = true
    }
    
    func loadData () {
        if isOwnProfile {
            self.username = user["username"] as! String!
        }
        
        let userRef = getFirebase("users/" + username)
        dispatch_barrier_sync(taskQueue) {
            userRef.observeSingleEventOfType(.Value, withBlock: { snapshot in
                if !(snapshot.value is NSNull) {
                    if var wholeName = (snapshot.value["First Name"] as? String) {
                        wholeName = (snapshot.value["First Name"] as? String)! + " " + (snapshot.value["Last Name"] as? String)!
                        self.nameLabel.text = wholeName
                        self.majorLabel.text = snapshot.value["Major"] as! String!
                        let graduationYear = snapshot.value["Graduation Year"] as! String!
                        self.graduationLabel.text = "Class of " + graduationYear
                        self.numDotsLabel.text = String((snapshot.value["dots"] as? Int)!)
                    
                        self.name = self.nameLabel.text!
                        self.major = self.majorLabel.text!
                        self.graduation = graduationYear
                        // self.numDots = Int(numDotsLabel.text!)!
                        print("data has been fetched: \(self.major), \(self.graduation), \(self.numDots)")
                    }
                }
            })
        }
        
        
    }
    
    func hideEditing () {
        if isOwnProfile {
            self.rightBarButton.enabled = true
            self.rightBarButton.title = "Edit"
            self.leftBarButton.enabled = false
            self.leftBarButton.title = ""
        } else {
            self.rightBarButton.enabled = false
            self.rightBarButton.title = ""
            self.leftBarButton.enabled = true
            self.leftBarButton.title = "Back"
        }
        
        // Hide text fields and button(s)
        self.nameTextField.hidden = true
        self.majorTextField.hidden = true
        self.graduationTextField.hidden = true
        self.changePhotoButton.hidden = true
        
        // Show labels
        self.nameLabel.hidden = false
        self.majorLabel.hidden = false
        self.graduationLabel.hidden = false
    }
    
    func showEditing () {
        // Display save button in top nav bar
        self.rightBarButton.enabled = true
        self.rightBarButton.title = "Save"
        self.leftBarButton.enabled = true
        self.leftBarButton.title = "Cancel"
        
        // Hide labels
        self.nameLabel.hidden = true
        self.majorLabel.hidden = true
        self.graduationLabel.hidden = true
        
        // Show text fields and button(s)
        self.nameTextField.hidden = false
        self.nameTextField.placeholder = self.name
        
        self.majorTextField.hidden = false
        self.majorTextField.placeholder = self.major
        self.graduationTextField.hidden = false
        self.graduationTextField.placeholder = self.graduation
        self.changePhotoButton.hidden = false
    }
    
    func displayUserData (needToRetrieveData:Bool) {
        self.nameLabel.text = self.name
        let fullNameArr = self.name.characters.split{$0 == " "}.map(String.init)
        let firstName = fullNameArr[0]
        self.coursesLabel.text = ("Courses \(firstName) can  tutor for:")
        self.majorLabel.text = self.major
        self.graduationLabel.text = ("Class of \(self.graduation)")
        self.numDotsLabel.text = String(user["dots"]!) as String!
        // Still need to display correct activity image
    }
    
    func saveInfo () -> Bool {
        self.major = self.majorTextField.text?.characters.count > 0 ? self.majorTextField.text! : self.major
        
        let valid:Bool = self.validateFields()
        
        // Save
        if valid {
            // Update global "user" variable
            let fullNameArr = self.name.characters.split{$0 == " "}.map(String.init)
            user["firstName"] = fullNameArr[0]
            user["lastName"] = fullNameArr[1]
            user["major"] = self.major
            user["graduationYear"] = self.graduation
            
            if self.newPhotoString != nil {
                // Update then revert photo string
                user["photoString"] = self.newPhotoString
                self.newPhotoString = nil
            }
            
            // Update Firebase
            let userRef = getFirebase("users/" + (user["username"] as! String!))
            userRef.updateChildValues([
                "First Name": user["firstName"] as! String!,
                "Last Name": user["lastName"] as! String!,
                "Major": self.major,
                "Graduation Year": self.graduation,
                "Photo String" : user["photoString"] as! String!
                ])
        }
        return valid
    }
    
    func validateFields () -> Bool {
        // Validate name
        let fullNameArr = self.nameTextField.text!.characters.split{$0 == " "}.map(String.init)
        if nameTextField.text!.characters.count > 1 && fullNameArr.count != 2{
            alert(self, description: "Please enter a valid first and last name.", okAction: UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
            return false
        } else if nameTextField.text!.characters.count > 1 && fullNameArr.count == 2 {
            self.name = self.nameTextField.text!
        }
        
        // Validate major -- how can we do this?
        
        // Validate graduation year
        if self.graduationTextField.text?.characters.count > 0 {
            if let year = Int(self.graduationTextField.text!){
                if year < 2015 || year > 2021{
                    print("Graduation \(self.graduation) is an invalid graduation date")
                    alert(self, description: "Please enter the expected year of your graduation.", okAction: UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
                    return false
                } else {
                    self.graduation = self.graduationTextField.text!
                    return true
                }
            } else{
                alert(self, description: "Please enter the expected year of your graduation.", okAction: UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))
                return false
            }
        }
        return true
    }
    
    func adjustButtonFunctionality () {
        if isOwnProfile {
            // If own profile, don't allow emails to self.
            self.emailButton.enabled = false
        } else {
            // If not own profile, don't allow profile editing
            self.rightBarButton.enabled = false
            self.rightBarButton.title = ""
        }
    }
    
    func displayUserPhoto () {
        getUserPhoto(self.username, imageView: self.photo)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return coursesCopy.0.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let idx = indexPath.row
        let cell = self.CoursesTableView.dequeueReusableCellWithIdentifier("courseCell", forIndexPath: indexPath)
        let course = (coursesCopy.0)[idx] + " " + (coursesCopy.1)[idx]
        cell.textLabel!.text = course
        return cell
    }
    
    @IBAction func onClickEmail(sender: AnyObject) {
        let userRef = getFirebase("users/" + self.username)
        userRef.observeSingleEventOfType(.Value, withBlock: { snapshot in
            if !(snapshot.value is NSNull) {
                if let email = snapshot.value["Email Address"] as? String {
                    let url = NSURL(string: "mailto:\(email)")
                    UIApplication.sharedApplication().openURL(url!)
                }
            }
        })
    }
    
    @IBAction func onClickRightBarButton(sender: AnyObject) {
        if self.rightBarButton.title == "Edit" {
            self.isEditing = true
            self.showEditing()
            self.emailButton.hidden = true
        } else if self.rightBarButton.title == "Save" {
            let success:Bool = self.saveInfo()
            if success {
                self.hideEditing()
                self.displayUserData(false)
                self.emailButton.hidden = false
            }
            
            // Hide any open keyboard
            self.textFieldShouldReturn(self.nameTextField)
            self.textFieldShouldReturn(self.majorTextField)
            self.textFieldShouldReturn(self.graduationTextField)
        }
    }
    
    @IBAction func onClickLeftBarButton(sender: AnyObject) {
        // Revert all fields back to previous values
        self.nameTextField.text = ""
        self.majorTextField.text = ""
        self.graduationTextField.text = ""
        self.displayUserPhoto()
        
        // Exit editing mode
        self.hideEditing()
        self.displayUserData(false)
        self.emailButton.hidden = false
        
        // Hide any open keyboard
        self.textFieldShouldReturn(self.nameTextField)
        self.textFieldShouldReturn(self.majorTextField)
        self.textFieldShouldReturn(self.graduationTextField)
    }
    
    
    // ImagePicker Functionality
    func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?) {
        
        // Encode the selected image
        let thumbnail = self.resizeImage(image, sizeChange: CGSize(width: 200, height: 200))
        let imageData = UIImageJPEGRepresentation(thumbnail, 1.0)
        let base64String = imageData!.base64EncodedStringWithOptions(.Encoding64CharacterLineLength)
        self.newPhotoString = base64String
        
        // Update the UI to display selected photo
        self.photo.image = thumbnail
        self.photo.contentMode = .ScaleAspectFit
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func resizeImage (imageObj:UIImage, sizeChange:CGSize)-> UIImage{
        let hasAlpha = false
        let scale: CGFloat = 0.0 // Automatically use scale factor of main screen
        
        UIGraphicsBeginImageContextWithOptions(sizeChange, !hasAlpha, scale)
        imageObj.drawInRect(CGRect(origin: CGPointZero, size: sizeChange))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        return scaledImage
    }
    
    @IBAction func onClickChangePhoto(sender: AnyObject) {
        self.imagePicker.allowsEditing = false
        self.imagePicker.sourceType = .PhotoLibrary
        
        self.presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.view.endEditing(true)
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
