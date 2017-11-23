//
//  FlickrPhotosCollectionViewController.swift
//  FlickrSearch
//
//  Created by Hsiao Ai LEE on 22/11/2017.
//  Copyright © 2017 Hsiao Ai LEE. All rights reserved.
//

import UIKit
import Social

final class FlickrPhotosCollectionViewController: UICollectionViewController {

    // MARK: - Properties
    fileprivate let reuseIdentifier = "FlickrCell"
    fileprivate let sectionInsets = UIEdgeInsets(top: 50.0, left: 20.0, bottom: 50.0, right: 20.0)
    fileprivate var searches = [FlickrSearchResults]()
    fileprivate let flickr = Flickr()        // Do the searching
    fileprivate let itemsPerRow: CGFloat = 3
    fileprivate var selectedPhotos = [FlickrPhoto]()
    fileprivate let shareTextLabel = UILabel()

    var largePhotoIndexPath: IndexPath? {
        // Whenever this property gets updated, the collection view needs to be updated. a didSet property observer is the safest place to manage this.
        didSet {

            var indexPaths = [IndexPath]()
            if let largePhotoIndexPath = self.largePhotoIndexPath {
                indexPaths.append(largePhotoIndexPath)
            }
            
            if let oldValue = oldValue {
                indexPaths.append(oldValue)
            }

            collectionView?.performBatchUpdates({
                self.collectionView?.reloadItems(at: indexPaths)
            }) { _ in

                if let largePhotoIndexPath = self.largePhotoIndexPath {
                    self.collectionView?.scrollToItem(
                        at: largePhotoIndexPath,
                        at: .centeredVertically,
                        animated: true)
                }
            }
        }
    }

    var sharing: Bool = false {
        didSet {
            collectionView?.allowsMultipleSelection = sharing
            collectionView?.selectItem(at: nil, animated: true, scrollPosition: UICollectionViewScrollPosition())
            selectedPhotos.removeAll(keepingCapacity: false)

            guard let shareButton = self.navigationItem.rightBarButtonItems?.first else {
                return
            }

            guard sharing else {
                navigationItem.setRightBarButtonItems([shareButton], animated: true)
                return
            }

            if let _ = largePhotoIndexPath {
                largePhotoIndexPath = nil
            }

            updateSharedPhotoCount()
            let sharingDetailItem = UIBarButtonItem(customView: shareTextLabel)
            navigationItem.setRightBarButtonItems([shareButton, sharingDetailItem], animated: true)
        }
    }

    @IBAction func share(_ sender: UIBarButtonItem) {

        guard !searches.isEmpty else {  return }

        guard !selectedPhotos.isEmpty else {
            sharing = !sharing
            return }

        guard sharing else { return }

        //TODO actually share photos!
        var imageArray = [UIImage]()
        for selectedPhoto in selectedPhotos {
            if let thumbnail = selectedPhoto.thumbnail {
                imageArray.append(thumbnail)
            }
        }
        
        if !imageArray.isEmpty {
            let shareScreen = UIActivityViewController(activityItems: imageArray, applicationActivities: nil)
            shareScreen.completionWithItemsHandler = {
                _ , _ , _, _ in self.sharing = false
            }
            let popverPresentaionController = shareScreen.popoverPresentationController
            popverPresentaionController?.barButtonItem = sender
            //popverPresentaionController?.permittedArrowDirections = .any
            present(shareScreen, animated: true, completion: nil)
        }
    }

}

private extension FlickrPhotosCollectionViewController {
    func photoForIndexPath(indexPath: IndexPath) -> FlickrPhoto {
        return searches[indexPath.section].searchResults[indexPath.row]
    }

    func updateSharedPhotoCount() {
        self.shareTextLabel.textColor = UIColor.CustomColor.wenderlichGreen
        self.shareTextLabel.text = "\(selectedPhotos.count) photos selected"
        self.shareTextLabel.sizeToFit()
    }
}

extension FlickrPhotosCollectionViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {

        let activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        textField.addSubview(activityIndicator)
        activityIndicator.frame = textField.bounds
        activityIndicator.startAnimating()

        let searchText = textField.text ?? ""
        flickr.searchFlickrForTerm(searchText) { results, error in
            activityIndicator.removeFromSuperview()

            if let error = error {
                print("Error searching: \(error)")
            }

            if let results = results {
                print("Found \(results.searchResults.count) matching \(results.searchTerm)")
                self.searches.insert(results, at: 0)
                self.collectionView?.reloadData()
            }
        }

        textField.text = nil
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - UICollectionViewDataSource
extension FlickrPhotosCollectionViewController {
    override func numberOfSections(in collectionView: UICollectionView) -> Int {
        return searches.count
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return searches[section].searchResults.count
    }

    // MARK: - Header
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {

        switch kind {
        case UICollectionElementKindSectionHeader:
            guard let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FlickrPhotoHeaderView", for: indexPath) as? FlickrPhotoHeaderCollectionReusableView else { return UICollectionReusableView() }
            headerView.headerLabel.text = searches[indexPath.section].searchTerm
            return headerView

        default :
            assert(false, "Unexpected element kind")

        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize {
        let width = self.collectionView?.bounds.width ?? 0
        var height = self.collectionView?.bounds.height ?? 0
        height *= 0.1
        return CGSize(width: width, height: height)
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath) as? FlickrPhotoCollectionViewCell else { return UICollectionViewCell() }

        var flickrPhoto = photoForIndexPath(indexPath: indexPath)
        cell.activityIndicator.stopAnimating()

        guard indexPath == largePhotoIndexPath else {
            cell.flickrPhotoImageView.image = flickrPhoto.thumbnail
            return cell
        }

        guard flickrPhoto.largeImage == nil else {
            cell.flickrPhotoImageView.image = flickrPhoto.largeImage
            return cell
        }

        cell.flickrPhotoImageView.image = flickrPhoto.thumbnail
        cell.activityIndicator.startAnimating()

        flickrPhoto.loadLargeImage {
            loadedFlickrPhoto, error in

            cell.activityIndicator.stopAnimating()

            guard loadedFlickrPhoto.largeImage != nil && error == nil else {
                return
            }

            if let cell = collectionView.cellForItem(at: indexPath) as? FlickrPhotoCollectionViewCell,
                indexPath == self.largePhotoIndexPath {
                cell.flickrPhotoImageView.image = loadedFlickrPhoto.largeImage
            }
        }
        return cell
    }
}

extension FlickrPhotosCollectionViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {

        if indexPath == largePhotoIndexPath {
            let flickrPhoto = photoForIndexPath(indexPath: indexPath)
            var size = collectionView.bounds.size
            size.height -= topLayoutGuide.length
            size.height -= (sectionInsets.top + sectionInsets.right)
            size.width -= (sectionInsets.left + sectionInsets.right)
            return flickrPhoto.sizeToFillWidthOfSize(size)
        }

        let paddingSpace = sectionInsets.left * (itemsPerRow + 1)
        let availableWidth = view.frame.width - paddingSpace
        let widthPerItem = availableWidth / itemsPerRow

        return CGSize(width: widthPerItem, height: widthPerItem)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {

        return sectionInsets
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {

        return sectionInsets.left
    }
}

// MARK: - UICollectionViewDelegate
extension FlickrPhotosCollectionViewController {
    override func collectionView(_ collectionView: UICollectionView,
                                 shouldSelectItemAt indexPath: IndexPath) -> Bool {

        guard !sharing else {
            return true
        }

        largePhotoIndexPath = largePhotoIndexPath == indexPath ? nil : indexPath
        return false
    }

    override func collectionView(_ collectionView: UICollectionView,
                                 didSelectItemAt indexPath: IndexPath) {
        guard sharing else { return }

        let photo = photoForIndexPath(indexPath: indexPath)
        selectedPhotos.append(photo)
        updateSharedPhotoCount()
    }

    override func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard sharing else {
            return
        }

        let photo = photoForIndexPath(indexPath: indexPath)

        if let index = selectedPhotos.index(of: photo) {
            selectedPhotos.remove(at: index)
            updateSharedPhotoCount()
        }
    }
}
