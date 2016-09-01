import Mapbox
import OLImageView
import UIKit

typealias JSON = [String: AnyObject]

class ViewController: UIViewController, MGLMapViewDelegate {

    let centerCoordinate = CLLocationCoordinate2D(latitude: 45.52, longitude: -122.672)
    let maxAlpha: CGFloat = 0.75

    var map: MGLMapView?

    var bubbleMode = true

    override func viewDidLoad() {
        super.viewDidLoad()
        map = MGLMapView(frame: view.bounds, styleURL: MGLStyle.darkStyleURLWithVersion(MGLStyleDefaultVersion))
        if let map = map {
            map.setCenterCoordinate(centerCoordinate, zoomLevel: 12, animated: false)
            map.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
            map.delegate = self
            view.addSubview(map)
        }
        let modeButton = UIButton(type: .Custom)
        modeButton.backgroundColor = UIColor.blackColor().colorWithAlphaComponent(0.5)
        modeButton.setTitle("Toggle Mode", forState: .Normal)
        modeButton.addTarget(self, action: #selector(toggleMode), forControlEvents: .TouchUpInside)
        modeButton.frame = CGRectMake(0, 0, 120, 35)
        modeButton.center = CGPointMake(view.bounds.size.width / 2, 50)
        modeButton.autoresizingMask = [.FlexibleLeftMargin, .FlexibleRightMargin, .FlexibleBottomMargin]
        modeButton.layer.cornerRadius = 10
        view.addSubview(modeButton)
        addAnnotations()
    }

    func addAnnotations() {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            var annotations = [MGLPointAnnotation]()
            if let path     = NSBundle.mainBundle().pathForResource("carts", ofType: "geojson"),
               let data     = NSData(contentsOfFile: path),
               let geojson  = try? NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.init(rawValue: 0)),
               let features = geojson["features"] as? [JSON] {
                for feature in features {
                    if let properties       = feature["properties"] as? JSON,
                       let name             = properties["Name"] as? String,
                       let geometry         = feature["geometry"] as? JSON,
                       let coordinateValues = geometry["coordinates"] as? [Double] {
                        let coordinate = CLLocationCoordinate2D(latitude: coordinateValues[1], longitude: coordinateValues[0])
                        let annotation = MGLPointAnnotation()
                        annotation.coordinate = coordinate
                        annotation.title = name
                        annotations.append(annotation)
                    }
                }
                dispatch_async(dispatch_get_main_queue()) {
                    self.map?.addAnnotations(annotations)
                }
            }
        }
    }

    func toggleMode() {
        bubbleMode = !bubbleMode
        if let annotations = map?.annotations {
            map!.removeAnnotations(annotations)
        }
        addAnnotations()
    }

    func mapView(mapView: MGLMapView, viewForAnnotation annotation: MGLAnnotation) -> MGLAnnotationView? {
        let identifier = "ViewAnnotation\(bubbleMode)"
        var annotationView = mapView.dequeueReusableAnnotationViewWithIdentifier(identifier)
        if annotationView == nil {
            annotationView = MGLAnnotationView(reuseIdentifier: identifier)
            if let annotationView = annotationView {
                if bubbleMode {
                    annotationView.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
                    annotationView.backgroundColor = UIColor.redColor().colorWithAlphaComponent(maxAlpha)
                    annotationView.layer.borderColor = UIColor.whiteColor().colorWithAlphaComponent(maxAlpha).CGColor
                    annotationView.layer.borderWidth = 2
                    annotationView.layer.cornerRadius = 20
                } else {
                    let imageView = OLImageView(image: OLImage(data: NSData(contentsOfFile: NSBundle.mainBundle().pathForResource("fire", ofType: "gif")!)!))
                    annotationView.frame = CGRect(x: 0, y: 0, width: 80, height: 80)
                    imageView.frame = annotationView.frame
                    annotationView.addSubview(imageView)
                }
            }
        }
        return annotationView
    }

    func distanceBetweenPoint(point: CGPoint, otherPoint: CGPoint) -> CGFloat {
        return sqrt(pow(point.x - otherPoint.x, 2) + pow(point.y - otherPoint.y, 2))
    }

    func mapViewDidFinishRenderingFrame(mapView: MGLMapView, fullyRendered: Bool) {
        if bubbleMode {
            let threshold: CGFloat = distanceBetweenPoint(CGPointMake(0, 0), otherPoint: mapView.center)
            let maxScale: CGFloat = 2.5
            if let annotations = mapView.annotations {
                for annotation in annotations {
                    if MGLCoordinateInCoordinateBounds(annotation.coordinate, mapView.visibleCoordinateBounds) {
                        let point = mapView.convertCoordinate(annotation.coordinate, toPointToView: mapView)
                        let distance = distanceBetweenPoint(mapView.center, otherPoint: point)
                        let scale = round(max(maxScale * ((threshold - distance) / threshold), 1.0) * 100) / 100
                        mapView.viewForAnnotation(annotation)?.layer.transform = CATransform3DMakeScale(scale, scale, 1)
                        let redFactor = (threshold - distance) / threshold
                        let blueFactor = 1 - redFactor
                        let alpha = max(maxAlpha * redFactor, 0.1)
                        let color = UIColor(red: redFactor, green: 0, blue: blueFactor, alpha: 1).colorWithAlphaComponent(alpha)
                        mapView.viewForAnnotation(annotation)?.backgroundColor = color
                    }
                }
            }
        }
    }

}
