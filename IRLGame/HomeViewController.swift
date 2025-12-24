//
//  HomeViewController.swift
//  IRLGame
//
//  Created by Srinivas Sankaranarayanan on 12/20/25.
//

import Foundation
import UIKit

final class HomeViewController: UIViewController {
    @IBOutlet weak var gameNameTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Home"
        
        gameNameTextField.delegate = self
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    @IBAction func CreateGame(_ sender: UIButton) {
        GameService.shared.createGame()
    }
    
    @IBAction func StartGame(_ sender: UIButton) {
        GameService.shared.startGame()
    }
    
    @IBAction func EndGame(_ sender: UIButton) {
        GameService.shared.endGame()
    }
    
    @IBAction func JoinGame(_ sender: UIButton) {
        let gameID = gameNameTextField?.text ?? ""
        GameService.shared.joinGame(id: gameID)
    }
    
    @IBAction func startARPressed(_ sender: UIButton) {
        let arVC = storyboard!.instantiateViewController(
            withIdentifier: "ARViewController"
        ) as! ARViewController

        navigationController?.pushViewController(arVC, animated: true)
    }
}

extension HomeViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
