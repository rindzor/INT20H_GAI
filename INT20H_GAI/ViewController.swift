//
//  ViewController.swift
//  INT20H_GAI
//
//  Created by  mac on 21.01.2021.
//

import UIKit
import ARCL
import CoreLocation
import MapKit

class ViewController: UIViewController {
    
    @IBOutlet weak var showMapSwitch: UISwitch!
    @IBOutlet weak var showPointsOfInterest: UISwitch!
    @IBOutlet weak var showRouteDirections: UISwitch!
    @IBOutlet weak var addressText: UITextField!
    @IBOutlet weak var searchResultTable: UITableView!
    @IBOutlet weak var refreshControl: UIActivityIndicatorView!
    
    var sceneLocationView = SceneLocationView()
    
    var locationManager = CLLocationManager()
    
    var mapSearchResults: [MKMapItem]?
    
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.headingFilter = kCLHeadingFilterNone
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.delegate = self
        locationManager.startUpdatingHeading()
        locationManager.startUpdatingLocation()

        locationManager.requestWhenInUseAuthorization()

        addressText.delegate = self
        searchResultTable.dataSource = self
        searchResultTable.delegate = self
        
    }
    
    @IBAction
    func toggledSwitch(_ sender: UISwitch) {
        if sender == showPointsOfInterest {
            showRouteDirections.isOn = !sender.isOn
            searchResultTable.reloadData()
        } else if sender == showRouteDirections {
            showPointsOfInterest.isOn = !sender.isOn
            searchResultTable.reloadData()
        }
    }
    
    @IBAction
    func tappedSearch(_ sender: Any) {
        guard let text = addressText.text, !text.isEmpty else {
            return
        }
        searchForLocation()
    }
    
//    func annotationNodeTouched(node: AnnotationNode) {
//        if let nodeView = node.view{
//            // Do stuffs with the nodeView
//            // ...
//        }
//        if let nodeImage = node.image{
//            // Do stuffs with the nodeImage
//            // ...
//        }
//    }
//
//    func locationNodeTouched(node: LocationNode) {
//        guard let name = node.tag else { return }
////        guard let selectedNode = node.childNodes.first(where: { $0.geometry is SCNBox }) else { return }
//
//    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
          
        sceneLocationView.frame = view.bounds
    }


}

// MARK: - UITextFieldDelegate
extension ViewController: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {

        if string == "\n" {
            DispatchQueue.main.async { [weak self] in
                self?.searchForLocation()
            }
        }

        return true
    }

}

// MARK: - DataSource
extension ViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if showPointsOfInterest.isOn {
            return 1
        }
        guard let mapSearchResults = mapSearchResults else {
            return 0
        }

        return mapSearchResults.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if showPointsOfInterest.isOn {
            let cell = tableView.dequeueReusableCell(withIdentifier: "OpenARCell", for: indexPath)
            guard let openARCell = cell as? OpenARCell else {
                return cell
            }
            openARCell.parentVC = self

            return openARCell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LocationCell", for: indexPath)
            guard let mapSearchResults = mapSearchResults,
                indexPath.row < mapSearchResults.count,
                let locationCell = cell as? LocationCell else {
                return cell
            }
            locationCell.locationManager = locationManager
            locationCell.mapItem = mapSearchResults[indexPath.row]

            return locationCell
        }
    }
}

// MARK: - UITableViewDelegate
extension ViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let mapSearchResults = mapSearchResults, indexPath.row < mapSearchResults.count else {
            return
        }
        let selectedMapItem = mapSearchResults[indexPath.row]
        getDirections(to: selectedMapItem)
    }

}


// MARK: - CLLocationManagerDelegate
extension ViewController: CLLocationManagerDelegate {

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

    }
}

extension ViewController {

    func createARVC() -> MainViewController {
        let arclVC = MainViewController.loadFromStoryboard()
        arclVC.showMap = showMapSwitch.isOn

        return arclVC
    }

    func getDirections(to mapLocation: MKMapItem) {
        refreshControl.startAnimating()

        let request = MKDirections.Request()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapLocation
        request.requestsAlternateRoutes = false

        let directions = MKDirections(request: request)

        directions.calculate(completionHandler: { response, error in
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.refreshControl.stopAnimating()
                }
            }
            if let error = error {
                return print("Error getting directions: \(error.localizedDescription)")
            }
            guard let response = response else {
                return assertionFailure("No error, but no response, either.")
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }

                let arclVC = self.createARVC()
                arclVC.routes = response.routes
                self.navigationController?.pushViewController(arclVC, animated: true)
            }
        })
    }

    /// Searches for the location that was entered into the address text
    func searchForLocation() {
        guard let addressText = addressText.text, !addressText.isEmpty else {
            return
        }

        showRouteDirections.isOn = true
        toggledSwitch(showRouteDirections)

        refreshControl.startAnimating()
        defer {
            self.addressText.resignFirstResponder()
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = addressText

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            defer {
                DispatchQueue.main.async { [weak self] in
                    self?.refreshControl.stopAnimating()
                }
            }
            if let error = error {
                return assertionFailure("Error searching for \(addressText): \(error.localizedDescription)")
            }
            guard let response = response, response.mapItems.count > 0 else {
                return assertionFailure("No response or empty response")
            }
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                print("!!!!!!!!!!!")
                print(response.mapItems)
                print("!!!!!!!!!!!")
                self.mapSearchResults = response.mapItems
                self.searchResultTable.reloadData()
            }
        }
    }
}

extension MKLocalSearch.Response {

    func sortedMapItems(byDistanceFrom location: CLLocation?) -> [MKMapItem] {
        guard let location = location else {
            return mapItems
        }

        return mapItems.sorted { (first, second) -> Bool in
            guard let d1 = first.placemark.location?.distance(from: location),
                let d2 = second.placemark.location?.distance(from: location) else {
                    return true
            }

            return d1 < d2
        }
    }

}

