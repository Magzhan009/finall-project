# JIHC Hall Booking App

## Student Information

**Name:** Magzhan Samatov
**Student ID:** 090217553070  
## App Description

JIHC Hall Booking App is a Flutter and Firebase based mobile application developed for students of Jambyl Innovation Higher College (JIHC).

The application allows students to:

* Book the Sport Hall
* Book the Act Hall
* Communicate with administrators through chat
* Track booking status (Pending, Approved, Rejected)
* Manage their profile information

The app uses Firebase Authentication, Cloud Firestore, and real-time data synchronization.

---

## Features

### Authentication

* Email and Password Registration
* Email and Password Login
* Google Sign-In
* Logout Functionality

### Hall Booking

* Sport Hall Booking
* Act Hall Booking
* Booking Status Tracking
* Real-time Booking Updates

### Chat System

* Real-time Messaging
* Send Text Messages
* Send Images from Gallery
* Send Images from Camera
* Edit Messages
* Delete Messages

### Firebase Features

* Firebase Authentication
* Cloud Firestore CRUD Operations
* Firestore Base64 Image Messages
* Real-time Synchronization
* Firestore Security Rules

### User Profile

* View Profile Information
* Update User Information
* Logout

---

## Screenshots

### Login Screen
<img width="658" height="1458" alt="image" src="https://github.com/user-attachments/assets/9474f273-8f07-4976-a960-867f291d1dfa" />


### Registration Screen


### Home Screen

<img width="644" height="1384" alt="image" src="https://github.com/user-attachments/assets/fb8775e2-fc46-4744-98e7-5f4853c94a22" />



### Booking Screen
<img width="624" height="1434" alt="image" src="https://github.com/user-attachments/assets/abc7e47d-dcb2-42c4-b7f9-d3bb2fd761de" />



### Chat Screen

<img width="630" height="1402" alt="image" src="https://github.com/user-attachments/assets/a02445a6-f033-4666-a052-4ca13491297e" />



### Profile Screen

<img width="654" height="1428" alt="image" src="https://github.com/user-attachments/assets/e942aa93-febd-40e3-9c3c-fcccd170e476" />



---

## Technologies Used

* Flutter
* Dart
* Firebase Authentication
* Cloud Firestore
* Google Sign-In

---

## Firebase Collections

### users

* uid
* name
* email
* createdAt

### bookings

* bookingId
* hallType
* userId
* status
* bookingDate
* createdAt

### chats

* chatId
* senderId
* message
* imageBase64
* createdAt

---

## Developer

**Magzhan Samatov**

JIHC Mobile Application Development Project
