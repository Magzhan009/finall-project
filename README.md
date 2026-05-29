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

<img width="658" height="1458" alt="image" src="https://github.com/user-attachments/assets/f4200114-076e-4d76-ae15-d687b4b67465" />


### Booking Screen
<img width="658" height="1458" alt="image" src="https://github.com/user-attachments/assets/b8477e35-7af2-4b8e-9afb-33b54fae3617" />


### Chat Screen

<img width="658" height="1458" alt="image" src="https://github.com/user-attachments/assets/d9375c9b-30b1-4412-933f-d78b7c14f750" />


### Profile Screen

<img width="658" height="1458" alt="image" src="https://github.com/user-attachments/assets/f97dd925-1ef9-47a6-b0df-e02350258d9c" />


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
