# JIHC Hall Booking & Messenger - Improved Project Prompt

## Project Identity

Build a Flutter mobile application called **JIHC Hall Booking & Messenger**.

- **Author:** Magzhan Samatuly
- **Student ID:** 090217553070
- **Primary accent color:** `#1982C4` Sky Blue
- **Platform:** Flutter with Firebase

The Profile/About screen must visibly include the author name, student ID, and
accent color swatch. Use `#1982C4` consistently for app bars, primary buttons,
active navigation icons, selected controls, and highlights.

## Goal

Create a student-focused app for JIHC college hall reservations. Students can
browse available halls, request a date and time, track approval status, and chat
with admins. Each submitted booking automatically creates a chat thread so
students and admins can discuss the request in real time.

## Design Direction

Base all screens on the supplied five-screen mockup:

- Airbnb-style hall cards with large hall visuals, capacity, status, and action
  buttons.
- Calendly-style calendar and time-slot selection.
- WhatsApp-style chat list, chat bubbles, timestamps, unread badges, and input
  bar.
- Compact mobile layout, light gray page background, white content surfaces,
  8-12px border radius, and clean card spacing.

## Required Screens

### Auth Flow

1. Splash screen
2. Onboarding: book halls instantly
3. Onboarding: chat with admins
4. Onboarding: track bookings
5. Login
6. Register

### Main Screens

7. Home/Dashboard
8. Notifications

### Hall Booking Flow

9. Hall list
10. Hall detail
11. Date picker
12. Time-slot picker
13. Booking form
14. Booking confirmed

### My Bookings

15. My bookings with All/Pending/Approved/Rejected tabs
16. Booking detail

### Messenger

17. Chats list
18. Booking chat
19. Admin direct chat
20. Group chat
21. New chat

### Profile and Settings

22. Profile
23. Edit profile
24. Settings
25. About/Identity

### Admin Panel

26. Admin all bookings
27. Admin booking action

## Firebase Structure

Use these Firestore collections:

- `/users/{uid}`: name, email, studentId, role, photoUrl, createdAt
- `/halls/{hallId}`: name, description, capacity, imageUrl, availableSlots,
  rules
- `/bookings/{bookingId}`: userId, userName, hallId, hallName, date, timeSlot,
  purpose, status, chatId, createdAt
- `/chats/{chatId}`: bookingId, participants, lastMessage, lastTime, isRead
- `/chats/{chatId}/messages/{messageId}`: senderId, senderName, text, imageBase64,
  timestamp, isRead

## Core Behavior

- Register new users with role `student`.
- Allow admins to approve or reject bookings.
- Students can cancel pending bookings.
- Create a chat automatically after a booking request is submitted.
- Write a system message when a booking is submitted, approved, or rejected.
- Use Firestore streams for live booking and chat updates.
- Store temporary chat image messages in Firestore as compressed Base64 strings.

## UI States

Handle loading, empty data, network errors, authentication errors, and image processing
progress. Empty bookings and chats should use simple visual states with concise
copy.

## Navigation

Use a four-tab bottom navigation bar:

- Home
- Bookings
- Chats
- Profile

Keep the active tab, selected controls, and primary actions in `#1982C4`.

## Submission Checklist

- 25 or more screens are present.
- Required identity block is visible.
- Booking CRUD flow is represented.
- Real-time chat structure is represented.
- Firebase Auth, Firestore, and Storage are planned or implemented.
- UI follows the supplied mockup style across every screen.
- App runs without analyzer issues or crashes.
