#!/bin/bash
cd "/Users/kevinbrown/Projects/FloRight/FloRIghtTemp/FloRIghtTemp"

echo "Adding all files to Git..."
git add .

echo "Committing files..."
git commit -m "Initial FloRight commit - dictation app with WhisperKit small.en"

echo "Adding GitHub remote..."
git remote add origin https://github.com/Metrostuff/FloRightTemp.git

echo "Pushing to GitHub..."
git push -u origin main
