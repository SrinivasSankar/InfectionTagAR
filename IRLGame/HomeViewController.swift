//
//  HomeViewController.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/20/25.
//

import Foundation
import UIKit

final class HomeViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Home"
    }

    @IBAction func startARPressed(_ sender: UIButton) {
        let arVC = storyboard!.instantiateViewController(
            withIdentifier: "ARViewController"
        ) as! ARViewController

        navigationController?.pushViewController(arVC, animated: true)
    }
}
