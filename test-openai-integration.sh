#!/bin/bash

# OpenAI Integration Test Script for Octopets (curl version)
# Run this script after starting the application to test the new endpoints

echo "🐾 Testing Octopets OpenAI Integration"
echo "======================================="

BASE_URL="https://localhost:7243"

# Test 1: Health Check
echo -e "\n1. Testing Health Check..."
response=$(curl -s -k "$BASE_URL/api/pet-analysis/health")
if [ $? -eq 0 ]; then
    echo "✅ Health Check Passed"
    echo "Response: $response"
else
    echo "❌ Health Check Failed"
fi

# Test 2: Pet Analysis
echo -e "\n2. Testing Pet Analysis..."
pet_data='{
    "petName": "Buddy",
    "petType": "Dog", 
    "breed": "Golden Retriever",
    "age": 3,
    "size": "Large",
    "temperamentDescription": "Friendly, energetic, loves people and other dogs",
    "specialNeeds": [],
    "activityLevel": "High"
}'

response=$(curl -s -k -X POST "$BASE_URL/api/pet-analysis/analyze" \
    -H "Content-Type: application/json" \
    -d "$pet_data")

if [ $? -eq 0 ]; then
    echo "✅ Pet Analysis Completed"
    echo "Response: $response" | jq '.' 2>/dev/null || echo "Response: $response"
else
    echo "❌ Pet Analysis Failed"
fi

# Test 3: Venue Recommendations
echo -e "\n3. Testing Venue Recommendations..."
preferences='["outdoor dining", "social environment"]'

response=$(curl -s -k -X POST "$BASE_URL/api/pet-analysis/recommendations?petType=Dog&breed=Labrador" \
    -H "Content-Type: application/json" \
    -d "$preferences")

if [ $? -eq 0 ]; then
    echo "✅ Venue Recommendations Retrieved"
    echo "Response: $response" | jq '.' 2>/dev/null || echo "Response: $response"
else
    echo "❌ Venue Recommendations Failed"
fi

# Test 4: Venue Description Generation
echo -e "\n4. Testing Venue Description Generation..."
allowed_pets='["dogs", "cats"]'

response=$(curl -s -k -X POST "$BASE_URL/api/pet-analysis/venue-description?venueName=The%20Pet%20Café&venueType=cafe" \
    -H "Content-Type: application/json" \
    -d "$allowed_pets")

if [ $? -eq 0 ]; then
    echo "✅ Venue Description Generated"
    echo "Response: $response" | jq '.' 2>/dev/null || echo "Response: $response"
else
    echo "❌ Venue Description Failed"
fi

echo -e "\n🎉 Testing Complete!"
echo "Note: If any tests failed, ensure:"
echo "1. The application is running (dotnet run --project apphost)"
echo "2. OpenAI API key is configured in appsettings.Development.json"
echo "3. You have sufficient OpenAI credits"