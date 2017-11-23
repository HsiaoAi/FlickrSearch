//
//  FlickrPhotoCollectionViewCell.swift
//  FlickrSearch
//
//  Created by Hsiao Ai LEE on 23/11/2017.
//  Copyright © 2017 Hsiao Ai LEE. All rights reserved.
//

import UIKit

class FlickrPhotoCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var flickrPhotoImageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    override var isSelected: Bool {
        didSet {
            flickrPhotoImageView.layer.borderWidth = isSelected ? 5 : 0
        }
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        flickrPhotoImageView.layer.borderColor = UIColor.CustomColor.wenderlichGreen.cgColor
        isSelected = false
    }

}
