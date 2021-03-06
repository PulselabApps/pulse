//
//  Model.swift
//  PulsetvOS
//
//  Created by Max Marze on 11/7/15.
//  Copyright © 2015 pulse. All rights reserved.
//

import Foundation
import Bolts
import Parse
import Alamofire

class Model {
    
    static let sharedInstance = Model()
    
    enum QuestionType {
        case MultipleChoice
        case FillInTheBlank
    }
    
    struct UserRankEntry {
        let name : String
        let score : Int
    }
    
    struct QuestionEntry {
        let question : Question
        var completed = false
    }
    
    class Question {
        let text : String
        let timeLimit : Int
        let questionType : QuestionType
        let answers : [String]
        
        init(text : String, timeLimit : Int, type : QuestionType, answers : [String]) {
            self.text = text
            self.timeLimit = timeLimit
            self.questionType = type
            self.answers = answers
        }
    }
    
    struct QuestionScores {
        var correct : Int
        var id : Int
        var incorrect : Int
    }
    
    private let className = "Math"
    private var questions = [QuestionEntry]()
    private var userRankings = [UserRankEntry]()
    private var questionScores = [QuestionScores]()
    private let bodyRequest = ""
    
    private var currentAnswerDistribution = [String : Int]()
    private var currentQuestionEntry : Int?
    private let headers = [
        "X-Parse-Application-Id": "AR6NF8FvJQFx0zurn9snBroZi2S68SCRBIRMudo7",
        "X-Parse-REST-API-Key": "ajmBURZkjuoxSKavw1xZnKpGFMypVP5j3JNVFks8",
        "Content-Type": "application/json"
    ]

    var mainVC : ViewController?
    
    private init() {
        //        PFUser.login
        
        
        Alamofire.request(.POST, "https://api.parse.com/1/functions/questions", headers: headers)
            .responseJSON { response in
                print(response.result.value!)
                if let resultJson = response.result.value?.valueForKey("result") {
                    if let questionsRaw = resultJson.valueForKey("questions") {
                        let questionsArray = questionsRaw[0] as! [AnyObject]
                        for question in questionsArray {
//                            print(question.valueForKey("questionText"))
                            let text = question.valueForKey("questionText") as! String
                            let timeLimitOpt = question.valueForKey("questionTime") as? Int
                            let questionType = question.valueForKey("questionType") as! String
                            let answers = question.valueForKey("answers") as! [String]
                            
                            let timeLimit = timeLimitOpt == nil ? -1 : timeLimitOpt!
                            let type : QuestionType = questionType == "MultipleChoice" ? QuestionType.MultipleChoice : QuestionType.FillInTheBlank
                            self.questions.append(QuestionEntry(question: Question(text: text, timeLimit: timeLimit, type: type, answers: answers), completed: false))

                        }
                        print("Finished Initalizing Questions")
                        if let currentQuestion = resultJson.valueForKey("currentQuestion"){
                            self.currentQuestionEntry = currentQuestion[0] as? Int
                        } else {
                            self.currentQuestionEntry = 0
                        }
                        self.initQuestionAnswers()
                        if let mainVCU = self.mainVC {
                            mainVCU.changeQuestion()
                        }
                    }
                }
//                debugPrint(response)
        }
//        curl -X POST \
//        -H "X-Parse-Application-Id: AR6NF8FvJQFx0zurn9snBroZi2S68SCRBIRMudo7" \
//        -H "X-Parse-REST-API-Key: ajmBURZkjuoxSKavw1xZnKpGFMypVP5j3JNVFks8" \
//        -H "Content-Type: application/json" \
//        -d '{}' \
//        https://api.parse.com/1/functions/questions
        
        // Get latest Session
    }
    
    func getFirstUnansweredQuestion() -> Question? {
        
        if let _ = currentQuestionEntry {
            
            if currentQuestionEntry! >= 2 {
                for (index, _) in questions.enumerate() {
                    questions[index].completed = false
                }
                currentQuestionEntry = 0
            }
            
            if !(questions[currentQuestionEntry!].completed) {
                return questions[currentQuestionEntry!].question
            }
        }
        var firstNew = -1
        for (index, _) in questions.enumerate() {
            if !questions[index].completed {
                if firstNew == -1 {
                    firstNew = index
                    currentQuestionEntry = index
                    return questions[index].question
                }
            }
        }
        return nil
//        if result.count > 0 {
//            currentQuestionEntry = questions.indexOf()
//            return result[0].question
//        } else {
//            return nil
//        }
//        return (result.count > 0 ? result[0].question : nil)
    }
    
    func getCurrentQuestion() -> Question? {
        if let x = currentQuestionEntry {
            return questions[x].question
        }
        
        return nil
    }
    
    func completeCurrentQuestion() -> Bool {
        if let _ = currentQuestionEntry {
            questions[currentQuestionEntry!].completed = true
            return true
        } else {
            return false
        }
    }
    
    func incrementCurrentQuestionInCloud() {
        
        Alamofire.request(.POST, "https://api.parse.com/1/functions/changeCurrentQuestion", headers: headers)
            .responseJSON { response in
                print("change question")
                self.initQuestionAnswers()
//                print(response.result.value!)
//                                debugPrint(response)
        }
    }
    
    func endSubmissionInCloud() {
        Alamofire.request(.POST, "https://api.parse.com/1/functions/endSubmissions", headers: headers)
            .responseJSON { response in
                print("end submission")
//                print(response.result.value!)
//                debugPrint(response)
        }
    }
    
    func getTopStudentsFromCloud() {
        userRankings.removeAll()
        Alamofire.request(.POST, "https://api.parse.com/1/functions/topStudents", headers: headers)
            .responseJSON { response in
                //                print(response.result.value!)
                if let resultJson = response.result.value?.valueForKey("result") {
                    if let results = resultJson as? [AnyObject] {
                        print("SCORES")
                        for result in results {
                            print(result.valueForKey("score") as! Int)
                            let name = result.valueForKey("username") as! String
                            let score = result.valueForKey("score") as! Int
                            self.userRankings.append(UserRankEntry(name: name, score: score))
                        }
                        
                        if !self.userRankings.isEmpty {
                            if let mainVCU = self.mainVC {
                                mainVCU.showRank()
                            }
                        }
                    }
                }
                self.getQuestionScoresFromCloud()
                //                debugPrint(response)
        }
    }
    
    func getTopStudents() -> [UserRankEntry] {
        return userRankings
    }
    
    func getQuestionScoresFromCloud() {
        Alamofire.request(.POST, "https://api.parse.com/1/functions/getScoresQuestion", headers: headers)
            .responseJSON { response in
                print("end score")
                //                print(response.result.value!)
                if let resultJson = response.result.value?.valueForKey("result") {
                    if let results = resultJson as? [AnyObject] {
                        for object in results {
                            let id = object.valueForKey("id") as! Int
                            let correct = object.valueForKey("correct") as! Int
                            let incorrect = object.valueForKey("incorrect") as! Int
                            self.questionScores.append(QuestionScores(correct: correct, id: id, incorrect: incorrect))
                        }

                    }
                    
                    if !self.questionScores.isEmpty {
                        if let mainVCU = self.mainVC {
                            mainVCU.showChartForCurrentQuestion()
                        }
                    }
                    self.getAnswerChoiceResultsFromCloud()
                }
                                debugPrint(response)
        }
    }
    
    func getQuestionScoresForCurrentQuestion() -> QuestionScores {
        return questionScores[currentQuestionEntry!]
    }
    
    func initQuestionAnswers() {
        Alamofire.request(.POST, "https://api.parse.com/1/functions/initQuestion", headers: headers)
            .responseJSON { response in
                print("end init question")
                //                print(response.result.value!)
                //                debugPrint(response)
        }
    }
    
    func getAnswerChoiceResultsFromCloud() {
        Alamofire.request(.POST, "https://api.parse.com/1/functions/answersForCurrentQuestion", headers: headers)
            .responseJSON { response in
                print("end init question")
                if let resultJson = response.result.value?.valueForKey("result") {
                    if let result = resultJson as? [String : Int] {
                        self.currentAnswerDistribution = result
                    }
                }
                if !self.currentAnswerDistribution.isEmpty {
                    if let mainVCU = self.mainVC {
                        mainVCU.showBarGraph()
                    }
                }
                //                print(response.result.value!)
                //                debugPrint(response)
        }
    }
    
    func getAnswerChoiceResults() -> ([String : Int], QuestionType) {
        return (currentAnswerDistribution, questions[currentQuestionEntry!].question.questionType)
    }
}