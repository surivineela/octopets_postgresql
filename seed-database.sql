-- Seed data for Octopets Production Database
-- This script inserts listings and reviews for demo purposes

-- Clear existing data (optional - remove if you want to keep existing data)
TRUNCATE TABLE "Reviews" CASCADE;
TRUNCATE TABLE "Listings" RESTART IDENTITY CASCADE;

-- Insert Listings with Photos as text array (just filenames, frontend adds path)
INSERT INTO "Listings" ("Id", "Name", "Description", "Price", "Address", "Location", "Type", "AllowedPets", "Amenities", "Rating", "Photos", "CreatedAt", "UpdatedAt") VALUES
(1, 'Pawsome Park', 'A spacious park with dedicated areas for dogs to run off-leash. Beautiful walking paths and rest areas for owners.', 0, '123 Park Avenue, New York, NY', '123 Park Avenue, New York, NY', 'park', '["dogs","cats"]', '["Water fountains","Waste stations","Benches","Shade areas"]', 4.5, '{"park1.jpg","park2.jpg"}', '2025-04-15T00:00:00Z', NULL),
(2, 'Whiskers Cafe', 'A cozy cafe with a special menu for pets. Indoor and outdoor seating available with pet-friendly accommodations.', 0, '456 Main Street, Seattle, WA', '456 Main Street, Seattle, WA', 'cafe', '["dogs","cats","small_mammals"]', '["Pet menu","Water bowls","Pet beds","Outdoor patio"]', 4.5, '{"cafe1.jpg","cafe2.jpg"}', '2025-04-18T00:00:00Z', NULL),
(3, 'Pet Haven Home', 'A beautiful vacation home with a fenced yard, pet doors, and all necessities for your furry friends.', 0, '789 Oak Road, San Francisco, CA', '789 Oak Road, San Francisco, CA', 'home', '["dogs","cats","birds","small_mammals"]', '["Fenced yard","Pet doors","Pet beds","Feeding stations","Pet toys"]', 5.0, '{"home1.jpg","home2.jpg"}', '2025-03-28T00:00:00Z', NULL),
(4, 'Pets & Pillows Hotel', 'Luxury hotel that welcomes pets of all sizes. Special pet services available including walking and grooming.', 0, '101 Sunset Blvd, Los Angeles, CA', '101 Sunset Blvd, Los Angeles, CA', 'hotel', '["dogs","cats","birds"]', '["Pet spa","Walking service","Pet menu","Pet sitting","Pet beds"]', 4.5, '{"hotel1.jpg","hotel2.jpg"}', '2025-04-02T00:00:00Z', NULL),
(5, 'Furry Friends Store', 'A pet store with a play area where pets are welcome to try toys and meet other animals.', 0, '246 Cherry Lane, Chicago, IL', '246 Cherry Lane, Chicago, IL', 'custom', '["dogs","cats","small_mammals","birds","other"]', '["Play area","Treats bar","Water stations","Pet events"]', 4.5, '{"store1.jpg","store2.jpg"}', '2025-04-12T00:00:00Z', NULL),
(6, 'Mooch''s Meow', 'A unique monkey-themed cafe where you can enjoy your coffee surrounded by banana decor and monkey-themed treats. Perfect for primate enthusiasts and their pets!', 0, '789 Banana Street, Miami, FL', '789 Banana Street, Miami, FL', 'cafe', '["dogs","cats","small_mammals","other"]', '["Banana treats","Monkey-themed play area","Climbing structures","Tropical atmosphere","Pet-friendly seating"]', 5.0, '{"moochs1.jpg","moochs2.jpg"}', '2025-04-28T00:00:00Z', NULL);

-- Insert Reviews
INSERT INTO "Reviews" ("Id", "ListingId", "Reviewer", "Rating", "Comment", "CreatedAt") VALUES
(101, 1, 'Alex Johnson', 5, 'My golden retriever loves this park! Plenty of space to run around.', '2025-04-15T00:00:00Z'),
(102, 1, 'Taylor Smith', 4, 'Clean and well-maintained. Would be perfect with more shade in summer.', '2025-04-10T00:00:00Z'),
(201, 2, 'Jamie Lee', 5, 'They have treats for my dog and great coffee for me!', '2025-04-18T00:00:00Z'),
(202, 2, 'Casey Morgan', 4, 'My cat enjoyed lounging on their special pet beds. Very accommodating staff.', '2025-04-05T00:00:00Z'),
(301, 3, 'Jordan Riley', 5, 'Best pet-friendly accommodation we''ve found! Our dogs loved the yard.', '2025-03-28T00:00:00Z'),
(302, 3, 'Riley Chen', 5, 'Even our parakeet was comfortable here. Thoughtful touches for all types of pets.', '2025-03-15T00:00:00Z'),
(401, 4, 'Sam Wilson', 5, 'They treated my dog like royalty! Room service even for pets.', '2025-04-02T00:00:00Z'),
(402, 4, 'Jesse Taylor', 4, 'Great amenities for pets, though a bit pricey.', '2025-03-20T00:00:00Z'),
(501, 5, 'Taylor Kim', 5, 'My ferret loved the play area! Staff was very knowledgeable about exotic pets.', '2025-04-12T00:00:00Z'),
(502, 5, 'Alex Rivera', 4, 'Great selection of products for all types of pets.', '2025-04-08T00:00:00Z'),
(601, 6, 'Charlie Simmons', 5, 'Such a fun atmosphere! My dog loved the banana-shaped treats and the staff was amazing.', '2025-04-28T00:00:00Z'),
(602, 6, 'Morgan Patel', 5, 'The monkey theme is adorable! Great place to bring your pets, they have special accommodations for all types of animals.', '2025-04-22T00:00:00Z'),
(603, 6, 'Sam Washington', 5, 'Best cafe experience ever! My cat actually enjoyed the climbing structures, and I loved the monkey-themed lattes!', '2025-05-01T00:00:00Z');

-- Update sequence values
SELECT setval('"Listings_Id_seq"', (SELECT MAX("Id") FROM "Listings"));
SELECT setval('"Reviews_Id_seq"', (SELECT MAX("Id") FROM "Reviews"));

-- Verify data
SELECT COUNT(*) as listing_count FROM "Listings";
SELECT COUNT(*) as review_count FROM "Reviews";
