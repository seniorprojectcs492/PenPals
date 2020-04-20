//
//  ChatsViewController.swift
//  PenPals
//
//  Created by MaseratiTim on 3/5/20.
//  Copyright © 2020 SeniorProject. All rights reserved.
//

import UIKit
import FirebaseFirestore

class ChatsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, RecentChatTableViewCellDelegate, UISearchResultsUpdating {
    
    
    
    @IBOutlet weak var tableView: UITableView!
    
    var recentChats: [NSDictionary] = []
    var filteredChats: [NSDictionary] = []
    
    //for lsitening for new messages
    var recentListener: ListenerRegistration!
    
    let searchController = UISearchController(searchResultsController: nil)
    
    //viewWillAppear & willDisapear make sure that the most
    // recent chat is listened for everytime the view is opened
    // not just the first time
    override func viewWillAppear(_ animated: Bool) {
        loadRecentChats()
        
        tableView.tableFooterView = UIView()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        recentListener.remove()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = true
        
        searchController.searchResultsUpdater = self
        searchController.dimsBackgroundDuringPresentation = false
        definesPresentationContext = true
        
        
        setTableViewHeader()
    }
    
    
    //MARK: IBActions
    
    @IBAction func createNewChat(_ sender: Any) {
        
        //segue to contact user's profile view once cell is tapped
        let userVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "contactsTableView") as! ConactsTableViewController
        
        self.navigationController?.pushViewController(userVC, animated: true)
        
        
        
    }
    
    //MARK: TableViewDataSource (functions required for table view)
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if searchController.isActive && searchController.searchBar.text != "" {
            return filteredChats.count
        } else {
            return recentChats.count
        }
        
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! RecentChatTableViewCell
                
        // generate cell with delegate
        cell.delegate = self
        
        var recent: NSDictionary!
        
        
        if searchController.isActive && searchController.searchBar.text != "" {
            recent = filteredChats[indexPath.row]
        } else {
            recent = recentChats[indexPath.row]
        }
        
        cell.generateCell(recentChat: recent, indexPath: indexPath)
        
        
        
        return cell
    }
    
    //MARK: TableViewDelegate functions (for mute/delete options)
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        var tempRecent: NSDictionary!
        
        // find user's cell location selected user in messages
        if searchController.isActive && searchController.searchBar.text != "" {
            tempRecent = filteredChats[indexPath.row]
        } else {
            tempRecent = recentChats[indexPath.row]
        }
        
        var muteTitle = "Unmute"
        var mute = false
        
        //check if the user is in the array of members that will recieve push notifications
        // if they are the user is not muted
        if (tempRecent[kMEMBERSTOPUSH] as! [String]).contains(FUser.currentId()) {
            
            muteTitle = "Mute"
            mute = true
        }
        
        // create delete button
        let deleteAction = UITableViewRowAction(style: .default, title: "Delete") { (action, indexPath) in
            
            self.recentChats.remove(at: indexPath.row)
            
            deleteRecentChat(recentChatDictionary: tempRecent)
            
            self.tableView.reloadData()
        }
        
        // create mute button
        let muteAction = UITableViewRowAction(style: .default, title: muteTitle) { (action, indexPath) in
            
            self.updatePushMembers(recent: tempRecent, mute: mute)
        }
        
        muteAction.backgroundColor = #colorLiteral(red: 0.1764705926, green: 0.4980392158, blue: 0.7568627596, alpha: 1)
        
        return [deleteAction, muteAction]
        
    }
    
    // tap message cell
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        var recent: NSDictionary!
        
        // find user's cell location selected user in messages
        if searchController.isActive && searchController.searchBar.text != "" {
            recent = filteredChats[indexPath.row]
        } else {
            recent = recentChats[indexPath.row]
        }
        
        //restart chat
        restartRecentChat(recent: recent)
        
        let messageVC = MessageViewController()
        //hide tabBar at bottom of screen
        messageVC.hidesBottomBarWhenPushed = true
        //pass these 4 values to message view
        messageVC.titleName = (recent[kWITHUSERFULLNAME] as? String)!
        messageVC.memberIds = (recent[kMEMBERS] as? [String])!
        messageVC.membersToPush = (recent[kMEMBERSTOPUSH] as? [String])!
        messageVC.chatRoomId = (recent[kCHATROOMID] as? String)!
        messageVC.isGroup = (recent[kTYPE] as! String) == kGROUP
        
        navigationController?.pushViewController(messageVC, animated: true)
    }
    
    //MARK: Create Message types
    var code = FUser.currentUser()?.language
    let semaphore = DispatchSemaphore(value: 0)
    var translatedText = ""
    
    
    //MARK: LoadRecentChats
    
    func loadRecentChats() {
        
        recentListener = reference(.Recent).whereField(kUSERID, isEqualTo: FUser.currentId()).addSnapshotListener({ (snapshot, error) in
            
            guard let snapshot = snapshot else { return }
            
            //stops duplicating the recent messages
            self.recentChats = []
            
            if !snapshot.isEmpty {
                
                // sort recent messages by date
                
                let sorted = ((dictionaryFromSnapshots(snapshots: snapshot.documents)) as NSArray).sortedArray(using: [NSSortDescriptor(key: kDATE, ascending: false)]) as! [NSDictionary]
                
                for recent in sorted {
                    
                    // makes application wait until api call is finished
                   // _ = self.semaphore.wait(wallTimeout: .distantFuture)
                    
                    
                    // if last message is empty, if there is a chatroomID and
                    //if recent has an ID to make sure it isnt a corrupt file
                    if recent[kLASTMESSAGE] as! String != "" && recent[kCHATROOMID] != nil && recent[kRECENTID] != nil {
                        
                        var text = recent[kLASTMESSAGE] as! String
                        
//                        // set the translation to the text
//                        self.initiateTranslation(text: text) { (tText) in
//                            self.translatedText = tText
//                            print("\(self.translatedText) !!!!!!!!")
//                            text = tText
//                            print("\(text) !!!!!!!!")
//
//                            self.semaphore.signal()
//
//                        }
//                        text = self.translatedText
//                        print("\(text) !!!!!!!!")
                                                
                        //add it to recent chat array
                        self.recentChats.append(recent)
                    }
                    
                    reference(.Recent).whereField(kCHATROOMID, isEqualTo: recent[kCHATROOMID] as! String).getDocuments(completion: { (snapshot, error) in
                        
                    })
                }
                
                self.tableView.reloadData()
            }
            
        })
        
    }
    
    //MARK: Translation Code
    
    func detectlanguage(text: String, completion: @escaping ( _ result: String) -> ()) {
        
        TranslationManager.shared.detectLanguage(forText: text) { (language) in
            if let language = language {
                print("The detected language was \(language)")
                completion(language)
            } else {
                print("language code not detected")
            }
        }
    }
    
    //make this a completion handler
    func initiateTranslation(text: String, completion: @escaping ( _ result: String) -> ()) {
        
        var text = text
        translate(text: text)
        TranslationManager.shared.translate { (translation) in
            if let translation = translation {
                text = translation
                print("The translation is... \(text)")
                completion(text)
            } else {
                print("language not translated")
            }
            
        }
    }
    
    
    func translate(text: String) {
        getTargetLangCode()
        TranslationManager.shared.textToTranslate = text
        //print("translate(\(text))")
        
    }
    
    func getTargetLangCode() {
        TranslationManager.shared.targetLanguageCode = code
        //print("getTargetLanguage(\(code!))")
    }
    
    //MARK: Custom tableViewHeader
    
    // creates group chat button
    func setTableViewHeader() {
        
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.width, height: 45))
        
        let buttonView = UIView(frame: CGRect(x: 0, y: 5, width: tableView.frame.width, height: 35))
        let groupButton = UIButton(frame: CGRect(x: tableView.frame.width - 110, y: 10, width: 100, height: 20))
        groupButton.addTarget(self, action: #selector(self.groupButtonPressed), for: .touchUpInside)
        groupButton.setTitle("New Group", for: .normal)
        let buttonColor = #colorLiteral(red: 0, green: 0.4784313725, blue: 1, alpha: 1)
        groupButton.setTitleColor(buttonColor, for: .normal)
        
        
        let lineView = UIView(frame: CGRect(x: 0, y: headerView.frame.height - 1, width: tableView.frame.width, height: 1))
        lineView.backgroundColor = #colorLiteral(red: 0.8039215803, green: 0.8039215803, blue: 0.8039215803, alpha: 1)
        
        buttonView.addSubview(groupButton)
        headerView.addSubview(buttonView)
        headerView.addSubview(lineView)
        
        tableView.tableHeaderView = headerView
    }
    
    
    @objc func groupButtonPressed() {
        print("hello")
    }
    
    
    //MARK: RecentChatsCell delegate
    
    func didTapAvatarImage(indexPath: IndexPath) {
        
        var recentChat: NSDictionary!
        
        if searchController.isActive && searchController.searchBar.text != "" {
            recentChat = filteredChats[indexPath.row]
        } else {
            recentChat = recentChats[indexPath.row]
        }
        
        //check if it is a private message or groupchat
        if recentChat[kTYPE] as! String == kPRIVATE {
            
            //display profile veiw
            
            // get the user ID
            reference(.User).document(recentChat[kWITHUSERUSERID] as! String).getDocument { (snapshot, error) in
                
                guard let snapshot = snapshot else { return }
                
                // we have a valid user
                if snapshot.exists {
                    
                    // put the user ina dictionary
                    let userDictionary = snapshot.data() as! NSDictionary
                    
                    // create a temporary user with that info
                    let tempUser = FUser(_dictionary: userDictionary)
                    
                    self.showUserProfile(user: tempUser)
                }
                
            }
        }
        
    }
    
    func showUserProfile(user: FUser) {
        
        let profileVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "profileView") as! ProfileViewTableViewController
        
        profileVC.user = user
        self.navigationController?.pushViewController(profileVC, animated: true)
    }
    
    
    //MARK: Search controller functions
    
    func filterContentForSearchText(searchText: String, scope: String = "All") {
        
        filteredChats = recentChats.filter({ (recentChat) -> Bool in
            
            return (recentChat[kWITHUSERFULLNAME] as! String).lowercased().contains(searchText.lowercased())
        })
        
        tableView.reloadData()
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        
        filterContentForSearchText(searchText: searchController.searchBar.text!)
    }
    
    //MARK: Helper functions
    
    //        func selectUserForChat(isGroup: Bool) {
    //
    //            let contactsVC = UIStoryboard.init(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "contactsView") as! ConactsTableViewController
    //
    //            contactsVC.isGroup = isGroup
    //
    //            self.navigationController?.pushViewController(contactsVC, animated: true)
    //        }
    
    func updatePushMembers(recent: NSDictionary, mute: Bool) {
        
        var membersToPush = recent[kMEMBERSTOPUSH] as! [String]
        
        if mute {
            //unmute user and ut them in unmute array
            let index = membersToPush.index(of: FUser.currentId())!
            membersToPush.remove(at: index)
        } else {
            //add members to mute array
            membersToPush.append(FUser.currentId())
        }
        
        //save changes to firebase
        updateExistingRecentWithNewValues(chatRoomId: recent[kCHATROOMID] as! String, members: recent[kMEMBERS] as! [String], withValues: [kMEMBERSTOPUSH : membersToPush])
        
    }
    
    
    
}
