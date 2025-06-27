//
//  FirestoreVocabularyManager.swift
//  Ferin
//
//  Created by Bankin ALO on 31.05.25.
//

import Foundation
import FirebaseFirestore

// MARK: - Data Models for Firestore
struct VocabularyCategory: Codable, Identifiable {
    var id: String
    let englishTitle: String
    let kurdishTitle: String
    let emoji: String
    let createdAt: Date
    let sortOrder: Int
    
    init(id: String, englishTitle: String, kurdishTitle: String, emoji: String, sortOrder: Int) {
        self.id = id
        self.englishTitle = englishTitle
        self.kurdishTitle = kurdishTitle
        self.emoji = emoji
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}

struct VocabularySubcategory: Codable, Identifiable {
    var id: String
    let englishTitle: String
    let kurdishTitle: String
    let categoryId: String
    let createdAt: Date
    let sortOrder: Int
    
    init(id: String, englishTitle: String, kurdishTitle: String, categoryId: String, sortOrder: Int) {
        self.id = id
        self.englishTitle = englishTitle
        self.kurdishTitle = kurdishTitle
        self.categoryId = categoryId
        self.createdAt = Date()
        self.sortOrder = sortOrder
    }
}

struct VocabularyEntry: Codable, Identifiable {
    var id: String
    let english: String
    let arabic: String
    let kurdish: String
    let gender: String? // "masculine", "feminine", "neuter", or nil
    let pronunciation: String? // Optional phonetic pronunciation
    let categoryId: String
    let subcategoryId: String
    let difficulty: String // "beginner", "intermediate", "advanced"
    let createdAt: Date
    let isCommon: Bool // Whether this is a commonly used word
    
    init(id: String = UUID().uuidString, english: String, arabic: String, kurdish: String, gender: String? = nil, 
         pronunciation: String? = nil, categoryId: String, subcategoryId: String, 
         difficulty: String = "beginner", isCommon: Bool = true) {
        self.id = id
        self.english = english
        self.arabic = arabic
        self.kurdish = kurdish
        self.gender = gender
        self.pronunciation = pronunciation
        self.categoryId = categoryId
        self.subcategoryId = subcategoryId
        self.difficulty = difficulty
        self.createdAt = Date()
        self.isCommon = isCommon
    }
    
    // Convenience method for learning language support
    func translation(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return english
        case .arabic: return arabic
        }
    }
}

// MARK: - Vocabulary Data for Upload
struct VocabularyData {
    let english: String
    let arabic: String
    let kurdish: String
    let gender: String?
    let pronunciation: String?
    let difficulty: String
    let isCommon: Bool
    
    init(english: String, arabic: String, kurdish: String, gender: String? = nil, pronunciation: String? = nil, difficulty: String = "beginner", isCommon: Bool = true) {
        self.english = english
        self.arabic = arabic
        self.kurdish = kurdish
        self.gender = gender
        self.pronunciation = pronunciation
        self.difficulty = difficulty
        self.isCommon = isCommon
    }
}

// MARK: - Lesson Entry Data Structure
struct LessonEntry: Codable, Identifiable {
    var id: String
    let kurdishWord: String
    let englishWord: String
    let arabicWord: String
    let kurdishExample: String
    let englishExample: String
    let arabicExample: String
    let imageUrl: String
    let type: String
    let createdAt: Date
    
    init(id: String = UUID().uuidString, kurdishWord: String, englishWord: String, arabicWord: String,
         kurdishExample: String, englishExample: String, arabicExample: String, imageUrl: String = "", type: String = "lesson") {
        self.id = id
        self.kurdishWord = kurdishWord
        self.englishWord = englishWord
        self.arabicWord = arabicWord
        self.kurdishExample = kurdishExample
        self.englishExample = englishExample
        self.arabicExample = arabicExample
        self.imageUrl = imageUrl
        self.type = type
        self.createdAt = Date()
    }
    
    // Convenience methods for learning language support
    func translation(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return englishWord
        case .arabic: return arabicWord
        }
    }
    
    func example(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return englishExample
        case .arabic: return arabicExample
        }
    }
}

// MARK: - Family Member Lesson Data
struct FamilyMemberLesson {
    let kurdishWord: String
    let englishWord: String
    let arabicWord: String
    let kurdishExample: String
    let englishExample: String
    let arabicExample: String
    
    init(kurdishWord: String, englishWord: String, arabicWord: String, kurdishExample: String, englishExample: String, arabicExample: String) {
        self.kurdishWord = kurdishWord
        self.englishWord = englishWord
        self.arabicWord = arabicWord
        self.kurdishExample = kurdishExample
        self.englishExample = englishExample
        self.arabicExample = arabicExample
    }
    
    // Convenience methods for learning language support
    func translation(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return englishWord
        case .arabic: return arabicWord
        }
    }
    
    func example(for learningLanguage: LearningLanguageManager.LearningLanguage) -> String {
        switch learningLanguage {
        case .english: return englishExample
        case .arabic: return arabicExample
        }
    }
}

// MARK: - Firestore Vocabulary Manager
@MainActor
class FirestoreVocabularyManager: ObservableObject {
    private let db = Firestore.firestore()
    
    // MARK: - Database Setup Functions
    
    /// Creates the initial category structure in Firestore
    func setupInitialCategories() async throws {
        let categories = [
            VocabularyCategory(id: "people_relationships", englishTitle: "People & Relationships", kurdishTitle: "Meriv û têkilî", emoji: "👨‍👩‍👧‍👦", sortOrder: 1),
            VocabularyCategory(id: "health_body", englishTitle: "Health & Body", kurdishTitle: "Beden û tenduristî", emoji: "🧠", sortOrder: 2),
            VocabularyCategory(id: "clothing_accessories", englishTitle: "Clothing & Accessories", kurdishTitle: "Kinc û aksesûwar", emoji: "👕", sortOrder: 3),
            VocabularyCategory(id: "home_living", englishTitle: "Home & Living", kurdishTitle: "Xanî / Mal", emoji: "🏠", sortOrder: 4),
            VocabularyCategory(id: "food_cooking", englishTitle: "Food & Cooking", kurdishTitle: "Xwarin û pijandin", emoji: "🍎", sortOrder: 5),
            VocabularyCategory(id: "in_city", englishTitle: "In the City", kurdishTitle: "Li bajar", emoji: "🏙️", sortOrder: 6),
            VocabularyCategory(id: "transport", englishTitle: "Transport", kurdishTitle: "Hatûçû / Trafîk", emoji: "🚗", sortOrder: 7),
            VocabularyCategory(id: "school_work", englishTitle: "School & Work", kurdishTitle: "Xwendegeh û kar", emoji: "🏫", sortOrder: 8),
            VocabularyCategory(id: "communication", englishTitle: "Communication", kurdishTitle: "Ragihandin", emoji: "📡", sortOrder: 9),
            VocabularyCategory(id: "free_time_sports", englishTitle: "Free Time & Sports", kurdishTitle: "Dema vala û spor", emoji: "⚽", sortOrder: 10),
            VocabularyCategory(id: "world_nature", englishTitle: "World & Nature", kurdishTitle: "Cîhan û xweza", emoji: "🌍", sortOrder: 11),
            VocabularyCategory(id: "numbers_measures", englishTitle: "Numbers & Measures", kurdishTitle: "Hejmara û mezinahî", emoji: "🔢", sortOrder: 12)
        ]
        
        for category in categories {
            do {
                let encoder = Firestore.Encoder()
                let data = try encoder.encode(category)
                try await db.collection("categories").document(category.id).setData(data)
            } catch {
                print("Error encoding category: \(error)")
                throw error
            }
        }
        
        print("✅ Created \(categories.count) categories successfully")
    }
    
    /// Creates subcategories for People & Relationships
    func setupPeopleRelationshipsSubcategories() async throws {
        let subcategories = [
            VocabularySubcategory(id: "family_relationships", englishTitle: "Family Relationships", kurdishTitle: "Têkiliyên merivayî/eqrebatî", categoryId: "people_relationships", sortOrder: 1),
            VocabularySubcategory(id: "greetings", englishTitle: "Greetings", kurdishTitle: "Silav û pîrozbayek", categoryId: "people_relationships", sortOrder: 2),
            VocabularySubcategory(id: "emotions", englishTitle: "Emotions", kurdishTitle: "Hest û sewq", categoryId: "people_relationships", sortOrder: 3),
            VocabularySubcategory(id: "personality", englishTitle: "Personality", kurdishTitle: "Kesayetî", categoryId: "people_relationships", sortOrder: 4),
            VocabularySubcategory(id: "social_interactions", englishTitle: "Social Interactions", kurdishTitle: "Têkiliyên civakî", categoryId: "people_relationships", sortOrder: 5),
            VocabularySubcategory(id: "introductions", englishTitle: "Introductions", kurdishTitle: "Nasandin", categoryId: "people_relationships", sortOrder: 6)
        ]
        
        for subcategory in subcategories {
            do {
                let encoder = Firestore.Encoder()
                let data = try encoder.encode(subcategory)
                try await db.collection("categories")
                    .document("people_relationships")
                    .collection("subcategories")
                    .document(subcategory.id)
                    .setData(data)
            } catch {
                print("Error encoding subcategory: \(error)")
                throw error
            }
        }
        
        print("✅ Created \(subcategories.count) subcategories for People & Relationships")
    }
    
    // MARK: - Vocabulary Upload Functions
    
    /// Uploads vocabulary entries for a specific category and subcategory
    func uploadVocabulary(categoryId: String, subcategoryId: String, vocabularyList: [VocabularyData]) async throws {
        let batch = db.batch()
        
        for vocabData in vocabularyList {
            let vocabEntry = VocabularyEntry(
                english: vocabData.english,
                arabic: vocabData.arabic,
                kurdish: vocabData.kurdish,
                gender: vocabData.gender,
                pronunciation: vocabData.pronunciation,
                categoryId: categoryId,
                subcategoryId: subcategoryId,
                difficulty: vocabData.difficulty,
                isCommon: vocabData.isCommon
            )
            
            let docRef = db.collection("categories")
                .document(categoryId)
                .collection("subcategories")
                .document(subcategoryId)
                .collection("vocabulary")
                .document(vocabEntry.id)
            
            do {
                let encoder = Firestore.Encoder()
                let data = try encoder.encode(vocabEntry)
                batch.setData(data, forDocument: docRef)
            } catch {
                print("Error encoding vocabulary entry: \(error)")
                throw error
            }
        }
        
        try await batch.commit()
        print("✅ Uploaded \(vocabularyList.count) vocabulary entries to \(categoryId)/\(subcategoryId)")
    }
    
    // MARK: - Predefined Vocabulary Data
    
    /// Family Relationships vocabulary for immediate upload
    func getFamilyRelationshipsVocabulary() -> [VocabularyData] {
        return [
            VocabularyData(english: "father", arabic: "الأب", kurdish: "bav", gender: "masculine", pronunciation: "bahv"),
            VocabularyData(english: "mother", arabic: "الأم", kurdish: "dayik", gender: "feminine", pronunciation: "dah-yik"),
            VocabularyData(english: "son", arabic: "الابن", kurdish: "kur", gender: "masculine", pronunciation: "koor"),
            VocabularyData(english: "daughter", arabic: "الابنة", kurdish: "keç", gender: "feminine", pronunciation: "kech"),
            VocabularyData(english: "brother", arabic: "الأخ", kurdish: "bira", gender: "masculine", pronunciation: "bee-rah"),
            VocabularyData(english: "sister", arabic: "الأخت", kurdish: "xwişk", gender: "feminine", pronunciation: "khwishk"),
            VocabularyData(english: "grandfather", arabic: "الجد", kurdish: "bapîr", gender: "masculine", pronunciation: "bah-peer"),
            VocabularyData(english: "grandmother", arabic: "الجدة", kurdish: "dapîr", gender: "feminine", pronunciation: "dah-peer"),
            VocabularyData(english: "uncle", arabic: "العم", kurdish: "mam", gender: "masculine", pronunciation: "mahm"),
            VocabularyData(english: "aunt", arabic: "العمة", kurdish: "xal", gender: "feminine", pronunciation: "khal"),
            VocabularyData(english: "cousin (male)", arabic: "ابن العم", kurdish: "kurê mam", gender: "masculine", pronunciation: "koo-reh mahm"),
            VocabularyData(english: "cousin (female)", arabic: "بنت العم", kurdish: "keça mam", gender: "feminine", pronunciation: "keh-cha mahm"),
            VocabularyData(english: "husband", arabic: "الزوج", kurdish: "mêr", gender: "masculine", pronunciation: "mair"),
            VocabularyData(english: "wife", arabic: "الزوجة", kurdish: "jin", gender: "feminine", pronunciation: "zheen"),
            VocabularyData(english: "family", arabic: "العائلة", kurdish: "malbat", gender: nil, pronunciation: "mahl-baht"),
            VocabularyData(english: "parents", arabic: "الوالدان", kurdish: "dê û bav", gender: nil, pronunciation: "day oo bahv"),
            VocabularyData(english: "children", arabic: "الأطفال", kurdish: "zarok", gender: nil, pronunciation: "zah-rohk"),
            VocabularyData(english: "relatives", arabic: "الأقارب", kurdish: "eqrebat", gender: nil, pronunciation: "eh-kreh-baht"),
            VocabularyData(english: "nephew", arabic: "ابن الأخ", kurdish: "kurê bira", gender: "masculine", pronunciation: "koo-reh bee-rah"),
            VocabularyData(english: "niece", arabic: "بنت الأخت", kurdish: "keça bira", gender: "feminine", pronunciation: "keh-cha bee-rah")
        ]
    }
    
    // MARK: - Family Members Lesson Data
    
    /// Family Members vocabulary lessons for upload
    func getFamilyMembersLessons() -> [FamilyMemberLesson] {
        return [
            FamilyMemberLesson(
                kurdishWord: "bav",
                englishWord: "Father",
                arabicWord: "الأب",
                kurdishExample: "Bavê min kar dike.",
                englishExample: "My father is working.",
                arabicExample: "والدي يعمل."
            ),
            FamilyMemberLesson(
                kurdishWord: "dê/dayika",
                englishWord: "Mother",
                arabicWord: "الأم",
                kurdishExample: "Dayika min xwarinê çêkir.",
                englishExample: "My mother cooked food.",
                arabicExample: "والدتي طبخت الطعام."
            ),
            FamilyMemberLesson(
                kurdishWord: "kurmet",
                englishWord: "Cousin (male)",
                arabicWord: "ابن العم",
                kurdishExample: "Kurmeta min li dibistanekê dixwîne.",
                englishExample: "My cousin studies at a school.",
                arabicExample: "ابن عمي يدرس في المدرسة."
            ),
            FamilyMemberLesson(
                kurdishWord: "xwişk",
                englishWord: "Sister",
                arabicWord: "الأخت",
                kurdishExample: "Ez bi xwişka xwe re bazdikevim.",
                englishExample: "I run with my sister.",
                arabicExample: "أركض مع أختي."
            ),
            FamilyMemberLesson(
                kurdishWord: "bira",
                englishWord: "Brother",
                arabicWord: "الأخ",
                kurdishExample: "Birayê min biçûktir e.",
                englishExample: "My brother is younger.",
                arabicExample: "أخي أصغر."
            ),
            FamilyMemberLesson(
                kurdishWord: "dapîr",
                englishWord: "Grandmother",
                arabicWord: "الجدة",
                kurdishExample: "Dapîra min ji çayê hez dike.",
                englishExample: "My grandmother loves tea.",
                arabicExample: "جدتي تحب الشاي."
            ),
            FamilyMemberLesson(
                kurdishWord: "bapîr",
                englishWord: "Grandfather",
                arabicWord: "الجد",
                kurdishExample: "Bapîra min li bajêr dijî.",
                englishExample: "My grandfather lives in the city.",
                arabicExample: "جدي يعيش في المدينة."
            ),
            FamilyMemberLesson(
                kurdishWord: "dotmam/keçap",
                englishWord: "Cousin (female)",
                arabicWord: "بنت العم",
                kurdishExample: "Dotmama min li Efrînê dijî.",
                englishExample: "My female cousin lives in Afrin.",
                arabicExample: "بنت عمي تعيش في عفرين."
            ),
            FamilyMemberLesson(
                kurdishWord: "met/xaltîk",
                englishWord: "Aunt",
                arabicWord: "العمة",
                kurdishExample: "Meta min qehwe çêkir.",
                englishExample: "My aunt made coffee.",
                arabicExample: "عمتي صنعت القهوة."
            ),
            FamilyMemberLesson(
                kurdishWord: "ap/mam",
                englishWord: "Uncle",
                arabicWord: "العم",
                kurdishExample: "Xalê min ji xwendina pirtûkan hez dike.",
                englishExample: "My uncle loves reading books.",
                arabicExample: "عمي يحب قراءة الكتب."
            ),
            FamilyMemberLesson(
                kurdishWord: "hevjîn/hevaljin",
                englishWord: "Partner / Spouse",
                arabicWord: "الشريك",
                kurdishExample: "Hevaljina min bi min re diçe bazarê.",
                englishExample: "My partner goes to the market with me.",
                arabicExample: "شريكي يذهب إلى السوق معي."
            ),
            FamilyMemberLesson(
                kurdishWord: "kur/law",
                englishWord: "Son",
                arabicWord: "الابن",
                kurdishExample: "Kurê min ji fûtbolê hez dike.",
                englishExample: "My son loves football.",
                arabicExample: "ابني يحب كرة القدم."
            ),
            FamilyMemberLesson(
                kurdishWord: "keç",
                englishWord: "Daughter",
                arabicWord: "الابنة",
                kurdishExample: "Keça min çîrokên xwe dixwîne.",
                englishExample: "My daughter reads her stories.",
                arabicExample: "ابنتي تقرأ قصصها."
            ),
            FamilyMemberLesson(
                kurdishWord: "birazî",
                englishWord: "Nephew",
                arabicWord: "ابن الأخ",
                kurdishExample: "Biraziyê min li parka lîstikê ye.",
                englishExample: "My nephew is at the playground.",
                arabicExample: "ابن أخي في الملعب."
            ),
            FamilyMemberLesson(
                kurdishWord: "xwarzî",
                englishWord: "Niece",
                arabicWord: "بنت الأخت",
                kurdishExample: "Xwarzîya min wêneyekî çêdike.",
                englishExample: "My niece is drawing a picture.",
                arabicExample: "بنت أختي ترسم صورة."
            )
        ]
    }
    
    /// Uploads family member lesson entries to Firestore
    func uploadFamilyMembersLessons() async throws {
        let familyLessons = getFamilyMembersLessons()
        let batch = db.batch()
        
        for lesson in familyLessons {
            let lessonEntry = LessonEntry(
                kurdishWord: lesson.kurdishWord,
                englishWord: lesson.englishWord,
                arabicWord: lesson.arabicWord,
                kurdishExample: lesson.kurdishExample,
                englishExample: lesson.englishExample,
                arabicExample: lesson.arabicExample,
                imageUrl: "", // Will be added manually later
                type: "lesson"
            )
            
            let docRef = db.collection("categories")
                .document("people_relationships")
                .collection("subcategories")
                .document("family_relationships")
                .collection("lessons")
                .document(lessonEntry.id)
            
            do {
                let encoder = Firestore.Encoder()
                let data = try encoder.encode(lessonEntry)
                batch.setData(data, forDocument: docRef)
            } catch {
                print("Error encoding family lesson: \(error)")
                throw error
            }
        }
        
        try await batch.commit()
        print("✅ Uploaded \(familyLessons.count) family member lessons to people_relationships/family_relationships")
    }
    
    // MARK: - Greetings & Farewells Vocabulary Data
    
    /// Greetings & Farewells vocabulary for upload
    func getGreetingsFarewellsVocabulary() -> [VocabularyData] {
        return [
            VocabularyData(english: "Good morning", arabic: "صباح الخير", kurdish: "Roj baş", pronunciation: "rohzh bahsh"),
            VocabularyData(english: "Good evening", arabic: "مساء الخير", kurdish: "Êvar baş", pronunciation: "ay-vahr bahsh"),
            VocabularyData(english: "Good night", arabic: "تصبح على خير", kurdish: "Şev baş", pronunciation: "shehv bahsh"),
            VocabularyData(english: "Goodbye", arabic: "مع السلامة", kurdish: "Bi xatirê te", pronunciation: "bee khah-tee-ray teh"),
            VocabularyData(english: "See you later", arabic: "أراك لاحقاً", kurdish: "Dîsa em ê bibînin", pronunciation: "dee-sah ehm ay bee-bee-neen"),
            VocabularyData(english: "Sweet dreams", arabic: "أحلام سعيدة", kurdish: "Xewn xweş", pronunciation: "kheh-oon khwehsh")
        ]
    }
    
    // MARK: - Greetings & Farewells Lesson Data
    
    /// Greetings & Farewells lesson entries for upload
    func getGreetingsFarewellsLessons() -> [FamilyMemberLesson] {
        return [
            FamilyMemberLesson(
                kurdishWord: "Roj baş",
                englishWord: "Good morning",
                arabicWord: "صباح الخير",
                kurdishExample: "Roj baş, ez hêvî dikim roja te baş be.",
                englishExample: "Good morning, I hope you have a good day.",
                arabicExample: "صباح الخير، أتمنى أن يكون يومك جميلاً."
            ),
            FamilyMemberLesson(
                kurdishWord: "Êvar baş",
                englishWord: "Good evening",
                arabicWord: "مساء الخير",
                kurdishExample: "Êvar baş, hevalno.",
                englishExample: "Good evening, my friend.",
                arabicExample: "مساء الخير، يا صديقي."
            ),
            FamilyMemberLesson(
                kurdishWord: "Şev baş",
                englishWord: "Good night",
                arabicWord: "تصبح على خير",
                kurdishExample: "Şev baş, xewa şirin bibî.",
                englishExample: "Good night, sweet dreams.",
                arabicExample: "تصبح على خير، أحلام سعيدة."
            ),
            FamilyMemberLesson(
                kurdishWord: "Bi xatirê te",
                englishWord: "Goodbye",
                arabicWord: "مع السلامة",
                kurdishExample: "Ez diçim, bi xatirê te.",
                englishExample: "I'm leaving, goodbye.",
                arabicExample: "أنا ذاهب، مع السلامة."
            ),
            FamilyMemberLesson(
                kurdishWord: "Dîsa em ê bibînin",
                englishWord: "See you later",
                arabicWord: "أراك لاحقاً",
                kurdishExample: "Dîsa em ê bibînin, heval.",
                englishExample: "See you later, friend.",
                arabicExample: "أراك لاحقاً، يا صديق."
            ),
            FamilyMemberLesson(
                kurdishWord: "Xewn xweş",
                englishWord: "Sweet dreams",
                arabicWord: "أحلام سعيدة",
                kurdishExample: "Şev baş û xewnên xweş.",
                englishExample: "Good night and sweet dreams.",
                arabicExample: "تصبح على خير وأحلام سعيدة."
            )
        ]
    }
    
    /// Uploads greetings & farewells lesson entries to Firestore
    func uploadGreetingsFarewellsLessons() async throws {
        let greetingsLessons = getGreetingsFarewellsLessons()
        let batch = db.batch()
        
        for lesson in greetingsLessons {
            let lessonEntry = LessonEntry(
                kurdishWord: lesson.kurdishWord,
                englishWord: lesson.englishWord,
                arabicWord: lesson.arabicWord,
                kurdishExample: lesson.kurdishExample,
                englishExample: lesson.englishExample,
                arabicExample: lesson.arabicExample,
                imageUrl: "", // Will be added manually later
                type: "lesson"
            )
            
            let docRef = db.collection("categories")
                .document("greetings_essentials")
                .collection("subcategories")
                .document("greetings_farewells")
                .collection("lessons")
                .document(lessonEntry.id)
            
            do {
                let encoder = Firestore.Encoder()
                let data = try encoder.encode(lessonEntry)
                batch.setData(data, forDocument: docRef)
            } catch {
                print("Error encoding greetings lesson: \(error)")
                throw error
            }
        }
        
        try await batch.commit()
        print("✅ Uploaded \(greetingsLessons.count) greetings & farewells lessons to greetings_essentials/greetings_farewells")
    }
    
    // MARK: - Polite Phrases Vocabulary Data
    
    /// Polite Phrases vocabulary for upload
    func getPolitePhrasesVocabulary() -> [VocabularyData] {
        return [
            VocabularyData(english: "Please", arabic: "من فضلك", kurdish: "Ji kerema xwe", pronunciation: "zhee keh-reh-mah khweh"),
            VocabularyData(english: "Thank you", arabic: "شكراً", kurdish: "Spas", pronunciation: "spahs"),
            VocabularyData(english: "You're welcome", arabic: "على الرحب والسعة", kurdish: "Ser çavan", pronunciation: "sehr cha-vahn"),
            VocabularyData(english: "Sorry", arabic: "آسف", kurdish: "Biborî", pronunciation: "bee-boh-ree"),
            VocabularyData(english: "Excuse me", arabic: "المعذرة", kurdish: "Biborî", pronunciation: "bee-boh-ree"),
            VocabularyData(english: "No problem", arabic: "لا مشكلة", kurdish: "pirsgirêk tune", pronunciation: "peer-sah too-neh")
        ]
    }
    
    // MARK: - Polite Phrases Lesson Data
    
    /// Polite Phrases lesson entries for upload
    func getPolitePhrasesLessons() -> [FamilyMemberLesson] {
        return [
            FamilyMemberLesson(
                kurdishWord: "Ji kerema xwe",
                englishWord: "Please",
                arabicWord: "من فضلك",
                kurdishExample: "Ji kerema xwe, ez dixwazim bi te re biaxivim.",
                englishExample: "Please, I want to speak with you.",
                arabicExample: "من فضلك، أريد أن أتحدث معك."
            ),
            FamilyMemberLesson(
                kurdishWord: "Spas",
                englishWord: "Thank you",
                arabicWord: "شكراً",
                kurdishExample: "Spas bo alîkariyê te.",
                englishExample: "Thank you for your help.",
                arabicExample: "شكراً لمساعدتك."
            ),
            FamilyMemberLesson(
                kurdishWord: "Ser çavan",
                englishWord: "You're welcome",
                arabicWord: "على الرحب والسعة",
                kurdishExample: "Ser çavan, tu her dikarî bipirse.",
                englishExample: "You're welcome, you can always ask.",
                arabicExample: "على الرحب والسعة، يمكنك أن تسأل دائماً."
            ),
            FamilyMemberLesson(
                kurdishWord: "Biborî",
                englishWord: "Sorry",
                arabicWord: "آسف",
                kurdishExample: "Biborî, ez şaşî kirim.",
                englishExample: "Sorry, I made a mistake.",
                arabicExample: "آسف، لقد أخطأت."
            ),
            FamilyMemberLesson(
                kurdishWord: "Biborî",
                englishWord: "Excuse me",
                arabicWord: "المعذرة",
                kurdishExample: "Biborî, ez dixwazim derkevim.",
                englishExample: "Excuse me, I want to leave.",
                arabicExample: "المعذرة، أريد أن أغادر."
            ),
            FamilyMemberLesson(
                kurdishWord: "pirsgirêk tune",
                englishWord: "No problem",
                arabicWord: "لا مشكلة",
                kurdishExample: "pirsgirêk tune, ez dikarim alîkariya te bikim.",
                englishExample: "No problem, I can help you.",
                arabicExample: "لا مشكلة، يمكنني مساعدتك."
            )
        ]
    }
    
    /// Uploads polite phrases lesson entries to Firestore
    func uploadPolitePhrasesLessons() async throws {
        let politeLessons = getPolitePhrasesLessons()
        let batch = db.batch()
        
        for lesson in politeLessons {
            let lessonEntry = LessonEntry(
                kurdishWord: lesson.kurdishWord,
                englishWord: lesson.englishWord,
                arabicWord: lesson.arabicWord,
                kurdishExample: lesson.kurdishExample,
                englishExample: lesson.englishExample,
                arabicExample: lesson.arabicExample,
                imageUrl: "", // Will be added manually later
                type: "lesson"
            )
            
            let docRef = db.collection("categories")
                .document("greetings_essentials")
                .collection("subcategories")
                .document("polite_phrases")
                .collection("lessons")
                .document(lessonEntry.id)
            
            do {
                let encoder = Firestore.Encoder()
                let data = try encoder.encode(lessonEntry)
                batch.setData(data, forDocument: docRef)
            } catch {
                print("Error encoding polite phrases lesson: \(error)")
                throw error
            }
        }
        
        try await batch.commit()
        print("✅ Uploaded \(politeLessons.count) polite phrases lessons to greetings_essentials/polite_phrases")
    }
    
    // MARK: - Introductions Vocabulary Data
    
    /// Introductions vocabulary for upload
    func getIntroductionsVocabulary() -> [VocabularyData] {
        return [
            VocabularyData(english: "What's your name?", arabic: "ما اسمك؟", kurdish: "Navê te çi ye?", pronunciation: "nah-vay teh chee yeh"),
            VocabularyData(english: "My name is…", arabic: "اسمي...", kurdish: "Navê min ... e", pronunciation: "nah-vay meen ... eh"),
            VocabularyData(english: "Nice to meet you", arabic: "تشرفنا", kurdish: "Ez kêfxweş bûm ku te nas kirim", pronunciation: "ehz kayf-khwehsh boom koo teh nahs kee-reem"),
            VocabularyData(english: "Where are you from?", arabic: "من أين أنت؟", kurdish: "Tu ji ku derê yî?", pronunciation: "too zhee koo deh-ray yee"),
            VocabularyData(english: "I'm from...", arabic: "أنا من...", kurdish: "Ez ji ... me", pronunciation: "ehz zhee ... meh")
        ]
    }
    
    // MARK: - Introductions Lesson Data
    
    /// Introductions lesson entries for upload
    func getIntroductionsLessons() -> [FamilyMemberLesson] {
        return [
            FamilyMemberLesson(
                kurdishWord: "Navê te çi ye?",
                englishWord: "What's your name?",
                arabicWord: "ما اسمك؟",
                kurdishExample: "Navê te çi ye?",
                englishExample: "What's your name?",
                arabicExample: "ما اسمك؟"
            ),
            FamilyMemberLesson(
                kurdishWord: "Navê min ... e",
                englishWord: "My name is…",
                arabicWord: "اسمي...",
                kurdishExample: "Navê min Bano ye.",
                englishExample: "My name is Bano.",
                arabicExample: "اسمي بانو."
            ),
            FamilyMemberLesson(
                kurdishWord: "Ez kêfxweş bûm ku te nas kirim",
                englishWord: "Nice to meet you",
                arabicWord: "تشرفنا",
                kurdishExample: "Ez kêfxweş bûm ku te nas kirim.",
                englishExample: "Nice to meet you.",
                arabicExample: "تشرفنا."
            ),
            FamilyMemberLesson(
                kurdishWord: "Tu ji ku derê yî?",
                englishWord: "Where are you from?",
                arabicWord: "من أين أنت؟",
                kurdishExample: "Tu ji ku derê yî? Ez ji Afrînê me.",
                englishExample: "Where are you from? I am from Afrin.",
                arabicExample: "من أين أنت؟ أنا من عفرين."
            ),
            FamilyMemberLesson(
                kurdishWord: "Ez ji ... me",
                englishWord: "I'm from...",
                arabicWord: "أنا من...",
                kurdishExample: "Ez ji Sûriyê me.",
                englishExample: "I'm from Syria.",
                arabicExample: "أنا من سوريا."
            )
        ]
    }
    
    /// Uploads introductions lesson entries to Firestore
    func uploadIntroductionsLessons() async throws {
        let introductionsLessons = getIntroductionsLessons()
        let batch = db.batch()
        
        for lesson in introductionsLessons {
            let lessonEntry = LessonEntry(
                kurdishWord: lesson.kurdishWord,
                englishWord: lesson.englishWord,
                arabicWord: lesson.arabicWord,
                kurdishExample: lesson.kurdishExample,
                englishExample: lesson.englishExample,
                arabicExample: lesson.arabicExample,
                imageUrl: "", // Will be added manually later
                type: "lesson"
            )
            
            let docRef = db.collection("categories")
                .document("greetings_essentials")
                .collection("subcategories")
                .document("introductions")
                .collection("lessons")
                .document(lessonEntry.id)
            
            do {
                let encoder = Firestore.Encoder()
                let data = try encoder.encode(lessonEntry)
                batch.setData(data, forDocument: docRef)
            } catch {
                print("Error encoding introductions lesson: \(error)")
                throw error
            }
        }
        
        try await batch.commit()
        print("✅ Uploaded \(introductionsLessons.count) introductions lessons to greetings_essentials/introductions")
    }
    
    // MARK: - Basic Questions Vocabulary Data
    
    /// Basic Questions vocabulary for upload
    func getBasicQuestionsVocabulary() -> [VocabularyData] {
        return [
            VocabularyData(english: "How are you?", arabic: "كيف حالك؟", kurdish: "Tu çawa yî?", pronunciation: "too cha-wah yee"),
            VocabularyData(english: "I'm fine, thanks", arabic: "أنا بخير، شكراً", kurdish: "Ez baş im, spas", pronunciation: "ehz bahsh eem spahs"),
            VocabularyData(english: "And you?", arabic: "وأنت؟", kurdish: "Tu çi?", pronunciation: "too chee"),
            VocabularyData(english: "Do you speak Kurdish?", arabic: "هل تتحدث الكردية؟", kurdish: "Tu bi Kurdî diaxivî?", pronunciation: "too bee koor-dee dee-ah-khee-vee"),
            VocabularyData(english: "A little", arabic: "قليلاً", kurdish: "Hinek", pronunciation: "hee-nehk"),
            VocabularyData(english: "I don't understand", arabic: "لا أفهم", kurdish: "Ez nizanim", pronunciation: "ehz nee-zah-neem")
        ]
    }
    
    // MARK: - Basic Questions Lesson Data
    
    /// Basic Questions lesson entries for upload
    func getBasicQuestionsLessons() -> [FamilyMemberLesson] {
        return [
            FamilyMemberLesson(
                kurdishWord: "Tu çawa yî?",
                englishWord: "How are you?",
                arabicWord: "كيف حالك؟",
                kurdishExample: "Tu çawa yî, hevalno?",
                englishExample: "How are you, my friend?",
                arabicExample: "كيف حالك، يا صديقي؟"
            ),
            FamilyMemberLesson(
                kurdishWord: "Ez baş im, spas",
                englishWord: "I'm fine, thanks",
                arabicWord: "أنا بخير، شكراً",
                kurdishExample: "Ez baş im, spas bo pirsê te.",
                englishExample: "I'm fine, thanks for asking.",
                arabicExample: "أنا بخير، شكراً لسؤالك."
            ),
            FamilyMemberLesson(
                kurdishWord: "Tu çi?",
                englishWord: "And you?",
                arabicWord: "وأنت؟",
                kurdishExample: "Ez baş im. Tu çi?",
                englishExample: "I'm fine. And you?",
                arabicExample: "أنا بخير. وأنت؟"
            ),
            FamilyMemberLesson(
                kurdishWord: "Tu bi Kurdî diaxivî?",
                englishWord: "Do you speak Kurdish?",
                arabicWord: "هل تتحدث الكردية؟",
                kurdishExample: "Tu bi Kurdî diaxivî an bi Tirkî?",
                englishExample: "Do you speak Kurdish or Turkish?",
                arabicExample: "هل تتحدث الكردية أم التركية؟"
            ),
            FamilyMemberLesson(
                kurdishWord: "Hinek",
                englishWord: "A little",
                arabicWord: "قليلاً",
                kurdishExample: "Ez bi Kurdî hinek dizanim.",
                englishExample: "I know a little Kurdish.",
                arabicExample: "أعرف القليل من الكردية."
            ),
            FamilyMemberLesson(
                kurdishWord: "Ez nizanim",
                englishWord: "I don't understand",
                arabicWord: "لا أفهم",
                kurdishExample: "Biborî, ez ev nabînim.",
                englishExample: "Sorry, I don't understand this.",
                arabicExample: "آسف، لا أفهم هذا."
            )
        ]
    }
    
    /// Uploads basic questions lesson entries to Firestore
    func uploadBasicQuestionsLessons() async throws {
        let basicQuestionsLessons = getBasicQuestionsLessons()
        let batch = db.batch()
        
        for lesson in basicQuestionsLessons {
            let lessonEntry = LessonEntry(
                kurdishWord: lesson.kurdishWord,
                englishWord: lesson.englishWord,
                arabicWord: lesson.arabicWord,
                kurdishExample: lesson.kurdishExample,
                englishExample: lesson.englishExample,
                arabicExample: lesson.arabicExample,
                imageUrl: "", // Will be added manually later
                type: "lesson"
            )
            
            let docRef = db.collection("categories")
                .document("greetings_essentials")
                .collection("subcategories")
                .document("basic_questions")
                .collection("lessons")
                .document(lessonEntry.id)
            
            do {
                let encoder = Firestore.Encoder()
                let data = try encoder.encode(lessonEntry)
                batch.setData(data, forDocument: docRef)
            } catch {
                print("Error encoding basic questions lesson: \(error)")
                throw error
            }
        }
        
        try await batch.commit()
        print("✅ Uploaded \(basicQuestionsLessons.count) basic questions lessons to greetings_essentials/basic_questions")
    }
    
    // MARK: - Yes/No & Confirmation Vocabulary Data
    
    /// Yes/No & Confirmation vocabulary for upload
    func getYesNoConfirmationVocabulary() -> [VocabularyData] {
        return [
            VocabularyData(english: "Yes", arabic: "نعم", kurdish: "Erê", pronunciation: "eh-ray"),
            VocabularyData(english: "No", arabic: "لا", kurdish: "Na", pronunciation: "nah"),
            VocabularyData(english: "Maybe", arabic: "ربما", kurdish: "Dibe", pronunciation: "dee-beh"),
            VocabularyData(english: "OK", arabic: "حسناً", kurdish: "Baş e", pronunciation: "bahsh eh"),
            VocabularyData(english: "I don't know", arabic: "لا أعرف", kurdish: "Ez nizanim", pronunciation: "ehz nee-zah-neem")
        ]
    }
    
    // MARK: - Yes/No & Confirmation Lesson Data
    
    /// Yes/No & Confirmation lesson entries for upload
    func getYesNoConfirmationLessons() -> [FamilyMemberLesson] {
        return [
            FamilyMemberLesson(
                kurdishWord: "Erê",
                englishWord: "Yes",
                arabicWord: "نعم",
                kurdishExample: "Erê, ez ê were.",
                englishExample: "Yes, I will come.",
                arabicExample: "نعم، سأحضر."
            ),
            FamilyMemberLesson(
                kurdishWord: "Na",
                englishWord: "No",
                arabicWord: "لا",
                kurdishExample: "Na, ez neçarim.",
                englishExample: "No, I can't.",
                arabicExample: "لا، لا أستطيع."
            ),
            FamilyMemberLesson(
                kurdishWord: "Dibe",
                englishWord: "Maybe",
                arabicWord: "ربما",
                kurdishExample: "Dibe ez ê têbim.",
                englishExample: "Maybe I'll join.",
                arabicExample: "ربما سأنضم."
            ),
            FamilyMemberLesson(
                kurdishWord: "Baş e",
                englishWord: "OK",
                arabicWord: "حسناً",
                kurdishExample: "Baş e, em ê destpê bikin.",
                englishExample: "OK, let's start.",
                arabicExample: "حسناً، دعونا نبدأ."
            ),
            FamilyMemberLesson(
                kurdishWord: "Ez nizanim",
                englishWord: "I don't know",
                arabicWord: "لا أعرف",
                kurdishExample: "Ez nizanim ku ew li ku ye.",
                englishExample: "I don't know where he is.",
                arabicExample: "لا أعرف أين هو."
            )
        ]
    }
    
    /// Uploads yes/no & confirmation lesson entries to Firestore
    func uploadYesNoConfirmationLessons() async throws {
        let yesNoLessons = getYesNoConfirmationLessons()
        let batch = db.batch()
        
        for lesson in yesNoLessons {
            let lessonEntry = LessonEntry(
                kurdishWord: lesson.kurdishWord,
                englishWord: lesson.englishWord,
                arabicWord: lesson.arabicWord,
                kurdishExample: lesson.kurdishExample,
                englishExample: lesson.englishExample,
                arabicExample: lesson.arabicExample,
                imageUrl: "", // Will be added manually later
                type: "lesson"
            )
            
            let docRef = db.collection("categories")
                .document("greetings_essentials")
                .collection("subcategories")
                .document("yes_no_confirmation")
                .collection("lessons")
                .document(lessonEntry.id)
            
            do {
                let encoder = Firestore.Encoder()
                let data = try encoder.encode(lessonEntry)
                batch.setData(data, forDocument: docRef)
            } catch {
                print("Error encoding yes/no confirmation lesson: \(error)")
                throw error
            }
        }
        
        try await batch.commit()
        print("✅ Uploaded \(yesNoLessons.count) yes/no & confirmation lessons to greetings_essentials/yes_no_confirmation")
    }
    
    // MARK: - Batch Upload Function
    
    /// Complete setup function that creates categories, subcategories, and uploads family vocabulary
    func setupCompleteDatabase() async throws {
        print("🚀 Starting complete database setup...")
        
        // Step 1: Create categories
        try await setupInitialCategories()
        
        // Step 2: Create subcategories for People & Relationships
        try await setupPeopleRelationshipsSubcategories()
        
        // Step 3: Upload family relationships vocabulary
        let familyVocab = getFamilyRelationshipsVocabulary()
        try await uploadVocabulary(
            categoryId: "people_relationships",
            subcategoryId: "family_relationships",
            vocabularyList: familyVocab
        )
        
        // Step 4: Upload family member lessons
        try await uploadFamilyMembersLessons()
        
        // Step 5: Upload greetings & farewells vocabulary
        let greetingsVocab = getGreetingsFarewellsVocabulary()
        try await uploadVocabulary(
            categoryId: "greetings_essentials",
            subcategoryId: "greetings_farewells",
            vocabularyList: greetingsVocab
        )
        
        // Step 6: Upload greetings & farewells lessons
        try await uploadGreetingsFarewellsLessons()
        
        // Step 7: Upload polite phrases vocabulary
        let politeVocab = getPolitePhrasesVocabulary()
        try await uploadVocabulary(
            categoryId: "greetings_essentials",
            subcategoryId: "polite_phrases",
            vocabularyList: politeVocab
        )
        
        // Step 8: Upload polite phrases lessons
        try await uploadPolitePhrasesLessons()
        
        // Step 9: Upload introductions vocabulary
        let introductionsVocab = getIntroductionsVocabulary()
        try await uploadVocabulary(
            categoryId: "greetings_essentials",
            subcategoryId: "introductions",
            vocabularyList: introductionsVocab
        )
        
        // Step 10: Upload introductions lessons
        try await uploadIntroductionsLessons()
        
        // Step 11: Upload basic questions vocabulary
        let basicQuestionsVocab = getBasicQuestionsVocabulary()
        try await uploadVocabulary(
            categoryId: "greetings_essentials",
            subcategoryId: "basic_questions",
            vocabularyList: basicQuestionsVocab
        )
        
        // Step 12: Upload basic questions lessons
        try await uploadBasicQuestionsLessons()
        
        // Step 13: Upload yes/no & confirmation vocabulary
        let yesNoVocab = getYesNoConfirmationVocabulary()
        try await uploadVocabulary(
            categoryId: "greetings_essentials",
            subcategoryId: "yes_no_confirmation",
            vocabularyList: yesNoVocab
        )
        
        // Step 14: Upload yes/no & confirmation lessons
        try await uploadYesNoConfirmationLessons()
        
        print("🎉 Complete database setup finished successfully!")
        print("📊 Total uploaded: \(familyVocab.count) family vocabulary entries + 15 family member lessons + 6 greetings & farewells vocabulary entries + 6 greetings & farewells lessons + 6 polite phrases vocabulary entries + 6 polite phrases lessons + 5 introductions vocabulary entries + 5 introductions lessons + 6 basic questions vocabulary entries + 6 basic questions lessons + 5 yes/no & confirmation vocabulary entries + 5 yes/no & confirmation lessons")
    }
}

// MARK: - Usage Examples and Helper Functions

extension FirestoreVocabularyManager {
    
    /// Example function showing how to upload custom vocabulary
    func uploadCustomVocabulary() async throws {
        let customVocab = [
            VocabularyData(english: "hello", arabic: "مرحبا", kurdish: "silav", pronunciation: "see-lahv"),
            VocabularyData(english: "goodbye", arabic: "وداعا", kurdish: "xatirê te", pronunciation: "khah-tee-ray teh"),
            VocabularyData(english: "thank you", arabic: "شكرا", kurdish: "spas", pronunciation: "spahs"),
            VocabularyData(english: "please", arabic: "من فضلك", kurdish: "ji kerema xwe", pronunciation: "zhee keh-reh-mah khweh")
        ]
        
        try await uploadVocabulary(
            categoryId: "people_relationships",
            subcategoryId: "greetings",
            vocabularyList: customVocab
        )
    }
    
    /// Function to fetch vocabulary for testing
    func fetchVocabulary(categoryId: String, subcategoryId: String) async throws -> [VocabularyEntry] {
        let snapshot = try await db.collection("categories")
            .document(categoryId)
            .collection("subcategories")
            .document(subcategoryId)
            .collection("vocabulary")
            .order(by: "english")
            .getDocuments()
        
        return snapshot.documents.compactMap { document in
            do {
                let data = document.data()
                let decoder = Firestore.Decoder()
                return try decoder.decode(VocabularyEntry.self, from: data)
            } catch {
                print("Error decoding vocabulary entry: \(error)")
                return nil
            }
        }
    }
} 