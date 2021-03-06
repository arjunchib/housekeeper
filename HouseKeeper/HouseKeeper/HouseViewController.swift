//
//  HouseViewController.swift
//  Open House
//
//  Created by Arjun Chib on 11/9/16.
//  Copyright © 2016 Profectus. All rights reserved.
//

import UIKit
import SnapKit
import Alamofire
import SwiftyJSON

class HouseViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var house: House
    let tableView = UITableView(frame: CGRect.zero, style: .grouped)
    let chart = Chart()
    let refreshControl = UIRefreshControl()
    
    init(house: House) {
        self.house = house
        super.init(nibName: nil, bundle: nil)
        house.syncCriteriaWithDreamHouse()
        MyHouses.shared.syncCriteria(for: house) { (success) in
            self.reloadCriteria()
            house.calculateRank()
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(HouseViewController.reloadCriteria), name: NSNotification.Name(rawValue: "reloadCriteria"), object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(HouseViewController.criteriaSelectorChanged), name: NSNotification.Name(rawValue: "radioChanged"), object: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        super.loadView()
        
        // VC
        view.backgroundColor = Style.whiteColor
        
        // Table View
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(HouseTableViewCell.self, forCellReuseIdentifier: "criterion")
        tableView.backgroundColor = Style.whiteColor
        tableView.contentInset.bottom = 44.0
        tableView.contentInset.top = 200.0
        tableView.setContentOffset(CGPoint(x: 0, y: -200), animated: true)
        tableView.addSubview(chart)
        view.addSubview(tableView)
        
        // Refresh
        refreshControl.addTarget(self, action: #selector(MyHousesViewController.refresh), for: .valueChanged)
        tableView.addSubview(refreshControl)
        
        refreshControl.bounds = refreshControl.bounds.offsetBy(dx: 0, dy: 200)
        
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        // Navigation Bar
        navigationItem.rightBarButtonItem = editButtonItem
        
        // Layout Subviews
        chart.snp.makeConstraints { (make) in
            make.width.equalToSuperview().inset(20.0)
            make.height.equalTo(180.0)
            make.centerX.equalToSuperview()
            make.top.equalTo(-180.0)
        }
        
        chart.setNeedsDisplay()
        chart.layoutSubviews()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateChart()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.updateChart()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        MyHouses.shared.syncCriteria(for: house) { (success) in
            self.reloadCriteria()
        }
    }
    
    func refresh() {
        MyHouses.shared.syncCriteria(for: house, completion: { (success) in
            self.reloadCriteria()
            self.refreshControl.endRefreshing()
        })
    }
    
    func updateChart() {
        for (index, _) in house.criteria.enumerated() {
            chart.updateValue(value: house.matchingRatio[index], for: index)
        }
    }
    
    // Networking
    func reloadCriteria() {
        print(house.criteria)
        self.tableView.reloadData()
    }
    
    // Rows
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        if isCriteriaRow(at: indexPath) {
            cell = CriterionTableViewCell(style: .default, reuseIdentifier: "criterion")
            cell.textLabel?.textColor = Style.redColor
            cell.selectionStyle = .none
            cell.textLabel!.text = house.criteria[indexPath.section][indexPath.row].name
            let type = house.criteria[indexPath.section][indexPath.row].type
            var criteriaSelector = CriteriaSelector()
            if type == .binary {
                criteriaSelector = BinaryCriteriaSelector()
            } else if type == .ternary {
                criteriaSelector = TernaryCriteriaSelector()
            }
            criteriaSelector.value = house.criteria[indexPath.section][indexPath.row].value
            cell.accessoryView = criteriaSelector
        } else {
            cell = AddCriterionTableViewCell(style: .default, reuseIdentifier: "criterion")
            cell.textLabel?.textColor = Style.grayColor
            cell.textLabel!.text = "Add Criterion"
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return isCriteriaRow(at: indexPath)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return Style.rowHeight
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if !isCriteriaRow(at: indexPath) {
            let modal = AddCriterionViewController()
            modal.house = house
            modal.category = Category.allValues[indexPath.section]
            modal.modalPresentationStyle = .overCurrentContext
            present(modal, animated: true, completion: {
                self.tableView.deselectRow(at: indexPath, animated: true)
            })
            NotificationCenter.default.post(Notification(name: Notification.Name(rawValue: "blur")))
        }
    }
    
    func criteriaSelectorChanged(notification: Notification) {
        let radio = notification.object as! RadioButton
        let criteriaSelector = radio.superview as! CriteriaSelector
        let cell = criteriaSelector.superview as! UITableViewCell
        let indexPath = tableView.indexPath(for: cell)
        if indexPath != nil {
            house.criteria[indexPath!.section][indexPath!.row].value = criteriaSelector.value
            handleCriteriaUpdate(indexPath: indexPath!)
        }
    }
    
    func handleCriteriaUpdate(indexPath: IndexPath) {
        house.calculateRank()
        updateChart()
        if Networking.token == "" && house.hid == 0 {
            return
        }
        let id = self.house.criteria[indexPath.section][indexPath.row].id
        let value = self.house.criteria[indexPath.section][indexPath.row].value
        let headers = generateHeaders()
        let parameters: Parameters = ["hid": house.hid, "id": id, "value": value]
        Alamofire.request(Networking.baseURL + "/updateCriterion", method: .post, parameters: parameters, encoding: JSONEncoding.default, headers: headers)
            .responseString { response in
                if (response.error != nil) {
                    print("Update criterion failed: " + (response.error?.localizedDescription)!)
                    return
                }
                let success = validate(statusCode: (response.response?.statusCode)!)
                if !success {
                    print("Update criterion failed: " + response.result.value!)
                }
        }
    }
    
    // Sections
    func numberOfSections(in tableView: UITableView) -> Int {
        return house.criteria.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return house.criteria[section].count + 1
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return Category.allValues[section].rawValue.capitalized
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.font = UIFont.systemFont(ofSize: 24.0, weight: UIFontWeightHeavy)
        header.textLabel?.textColor = Style.blackColor
        header.contentView.backgroundColor = Style.whiteColor
        header.layer.zPosition = 0
        header.textLabel?.text = header.textLabel?.text?.capitalized
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 60
    }
    
    // Editing
    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        self.tableView.setEditing(editing, animated: animated)
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        var actions = [UITableViewRowAction]()
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { (action, indexPath) in
            self.house.removeCriterion(index: indexPath.row, from: indexPath.section)
            self.reloadCriteria()
        }
        if !self.house.criteria[indexPath.section][indexPath.row].isDream {
            actions.append(delete)
        }
        return actions
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        if !self.house.criteria[indexPath.section][indexPath.row].isDream {
            return .delete
        }
        return .none
    }
    
    // Move Rows
    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
//        return isCriteriaRow(at: indexPath)
        return false
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let rowToMove = house.criteria[sourceIndexPath.section][sourceIndexPath.row]
        house.criteria[sourceIndexPath.section].remove(at: sourceIndexPath.row)
        house.criteria[destinationIndexPath.section].insert(rowToMove, at: destinationIndexPath.row)
    }
    
    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        if sourceIndexPath.section != proposedDestinationIndexPath.section {
            return sourceIndexPath
        }
        if proposedDestinationIndexPath.row >= house.criteria[proposedDestinationIndexPath.section].count {
            return sourceIndexPath
        }
        return proposedDestinationIndexPath
    }
    
    // Header
    
    // Utility
    func isCriteriaRow(at indexPath: IndexPath) -> Bool {
        return indexPath.row < house.criteria[indexPath.section].count
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}
