# BorrowBuddy

BorrowBuddy is an iOS app for lending and borrowing tools with neighbors. People list tools, find them on a map, reserve them with LendCredits, and return them with photos and a due date.

## Run the app

1. Open `BorrowBuddy.xcodeproj` in Xcode.
2. Select the **BorrowBuddy** scheme.
3. Choose an iPhone or iPad simulator and press Run.

The phone step does not send a text message. Enter any phone number, then use the code **123456**.

On the simulator, Face ID shows a grey screen and then continues. A new account starts with **1000 LendCredits**.

## What you can do

- Create an account, confirm a phone number, and save a shed location.
- Browse tools on a map and in a list, including tools near the saved location.
- Reserve a tool, pick it up, message the other person, and return it.
- Edit the profile photo, name, and neighborhood from **Profile → Edit Profile**.
- Buy more LendCredits from the wallet. The simulator uses `BorrowBuddy/Store/BorrowBuddy.storekit`.

## Backend

The app uses Firebase Authentication and Cloud Firestore. The Firebase project is [borrowbuddy-41e2d](https://console.firebase.google.com/project/borrowbuddy-41e2d/overview).

Account details, including the profile photo, name, and neighborhood, are stored on the signed-in user's document in Firestore.

## Tests

The test target is **BorrowBuddyTests**. In Xcode, choose **Product → Test**, or run the BorrowBuddy scheme tests from the Test navigator.
