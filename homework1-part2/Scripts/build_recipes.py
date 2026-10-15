#!/usr/bin/env python3
"""Builds PlatePlan/Resources/recipes.json from the hand-written recipes below.

Every recipe follows the app's simplicity rules (checked at the bottom):
  * a well-known dish that US households commonly cook
  * at most 10 ingredients you'd need to buy (pantry staples like salt and oil don't count)
  * at most 8 steps
  * only ingredients sold at any US grocery store, in US units

Ingredient names must come from CATALOG so the shopping list can merge them across
recipes, price them, and the AI scanner can match photo ingredients to recipes.

Nutrition is an estimate per serving (checked against protein/carbs/fat).
Prices are estimated US supermarket prices; they power the shopping list's money features.

Run:  python3 Scripts/build_recipes.py
"""
import json
from pathlib import Path

RESOURCES = Path(__file__).resolve().parent.parent / "PlatePlan" / "Resources"
OUT = RESOURCES / "recipes.json"
CATALOG_OUT = RESOURCES / "ingredients.json"

# Grocery aisles, in the order a shopping trip usually goes.
AISLES = [
    "Produce", "Meat & Seafood", "Dairy & Eggs", "Bakery & Tortillas", "Pasta, Rice & Grains",
    "Canned & Jarred", "Condiments & Sauces", "Spices & Baking", "Frozen", "Pantry Staples",
]

# Each ingredient: (name, sold_by, package, size, unit, price_usd, perishable)
#   sold_by  "each"    priced per item (size is 1 of `unit`)
#            "weight"  priced per lb, bought to the nearest 1/4 lb
#            "package" priced per package holding `size` `unit`
#   perishable  goes bad within about a week once bought/opened (used to estimate food waste)
CATALOG = {
    "Produce": [
        ("Yellow onion", "each", "1 onion", 1, "", 0.90, False),
        ("Red onion", "each", "1 onion", 1, "", 1.10, False),
        ("Garlic", "package", "1 head (about 10 cloves)", 10, "clove", 0.60, False),
        ("Ginger", "package", "1 piece (about 4 tbsp grated)", 4, "tbsp", 0.80, False),
        ("Bell pepper", "each", "1 pepper", 1, "", 1.25, True),
        ("Broccoli", "each", "1 head", 1, "head", 2.00, True),
        ("Zucchini", "each", "1 zucchini", 1, "", 1.00, True),
        ("Cucumber", "each", "1 cucumber", 1, "", 0.90, True),
        ("Carrots", "package", "1 lb bag (about 6)", 6, "", 1.29, False),
        ("Celery", "package", "1 bunch (about 8 stalks)", 8, "stalk", 1.99, True),
        ("Baby potatoes", "package", "1.5 lb bag", 1.5, "lb", 3.99, False),
        ("Russet potatoes", "each", "1 potato", 1, "", 0.80, False),
        ("Romaine lettuce", "each", "1 head", 1, "head", 2.29, True),
        ("Spinach", "package", "5 oz bag (about 5 cups)", 5, "cup", 2.99, True),
        ("Coleslaw mix", "package", "14 oz bag (about 6 cups)", 6, "cup", 2.49, True),
        ("Tomato", "each", "1 tomato", 1, "", 0.80, True),
        ("Cherry tomatoes", "package", "1 pint", 1, "pint", 3.49, True),
        ("Avocado", "each", "1 avocado", 1, "", 1.25, True),
        ("Lemon", "each", "1 lemon", 1, "", 0.70, False),
        ("Lime", "each", "1 lime", 1, "", 0.40, False),
        ("Green onions", "package", "1 bunch (about 6)", 6, "", 0.99, True),
        ("Fresh basil", "package", "1 bunch", 1, "bunch", 2.49, True),
        ("Fresh cilantro", "package", "1 bunch", 1, "bunch", 0.99, True),
        ("Bananas", "each", "1 banana", 1, "", 0.30, True),
        ("Apples", "each", "1 apple", 1, "", 0.90, False),
        ("Mixed berries", "package", "12 oz container (about 2 cups)", 2, "cup", 4.49, True),
        ("Asparagus", "package", "1 bunch", 1, "bunch", 3.49, True),
    ("Mushrooms", "package", "8 oz container", 8, "oz", 2.49, True),
    ("Cauliflower", "each", "1 head", 1, "head", 3.49, True),
    ("Eggplant", "each", "1 eggplant", 1, "", 1.79, True),
    # Tofu and hummus sit in the refrigerated case by the produce.
    ("Extra-firm tofu", "package", "14 oz block", 14, "oz", 2.49, True),
    ("Hummus", "package", "10 oz tub (about 1¼ cups)", 1.25, "cup", 3.99, True),
    ],
    "Meat & Seafood": [
        ("Boneless chicken thighs", "weight", "per lb", 1, "lb", 3.49, True),
        ("Bone-in chicken thighs", "weight", "per lb", 1, "lb", 1.99, True),
        ("Chicken breast", "weight", "per lb", 1, "lb", 4.29, True),
        ("Rotisserie chicken", "each", "1 whole chicken", 1, "", 7.99, True),
        ("Ground beef", "weight", "per lb", 1, "lb", 5.49, True),
        ("Flank steak", "weight", "per lb", 1, "lb", 9.99, True),
        ("Breakfast sausage", "package", "1 lb roll", 1, "lb", 4.49, True),
        ("Boneless pork chops", "each", "1 chop", 1, "", 2.50, True),
        ("Salmon fillets", "each", "1 fillet (6 oz)", 1, "", 4.50, True),
        ("White fish fillets", "each", "1 fillet (6 oz, cod or tilapia)", 1, "", 3.00, True),
        ("Shrimp", "package", "1 lb bag, frozen", 1, "lb", 8.99, False),
    ],
    "Dairy & Eggs": [
        ("Eggs", "package", "1 dozen", 12, "", 3.49, False),
        ("Milk", "package", "half gallon (8 cups)", 8, "cup", 2.99, True),
        ("Butter", "package", "1 lb (4 sticks, 2 cups)", 2, "cup", 4.99, False),
        ("Heavy cream", "package", "1 pint (2 cups)", 2, "cup", 4.29, True),
        ("Shredded cheddar", "package", "8 oz bag (2 cups)", 2, "cup", 2.99, True),
        ("Cheddar slices", "package", "10-slice pack", 10, "slice", 3.29, False),
        ("American cheese slices", "package", "16-slice pack", 16, "slice", 2.99, False),
        ("Grated Parmesan", "package", "8 oz container (about 2½ cups)", 2.5, "cup", 4.49, False),
        ("Shredded mozzarella", "package", "8 oz bag (2 cups)", 2, "cup", 2.99, True),
        ("Ricotta", "package", "15 oz container (about 1¾ cups)", 1.75, "cup", 3.49, True),
        ("Feta cheese", "package", "6 oz container (about 1½ cups)", 1.5, "cup", 3.99, True),
        ("Sour cream", "package", "16 oz container (2 cups)", 2, "cup", 2.29, True),
        ("Plain Greek yogurt", "package", "32 oz tub (4 cups)", 4, "cup", 5.49, True),
    ("Paneer", "package", "8 oz block", 8, "oz", 4.99, True),
    ],
    "Bakery & Tortillas": [
        ("Sandwich bread", "package", "1 loaf (about 20 slices)", 20, "slice", 2.99, True),
        ("Flour tortillas", "package", "8-pack", 8, "", 2.99, False),
        ("Hamburger buns", "package", "8-pack", 8, "", 2.49, True),
        ("Naan", "package", "2-pack", 2, "", 3.49, True),
        ("Pita bread", "package", "6-pack", 6, "", 2.99, True),
        ("Taco shells", "package", "12-pack", 12, "", 2.49, False),
    ("Corn tortillas", "package", "30-pack", 30, "", 2.79, False),
    ],
    "Pasta, Rice & Grains": [
        ("Spaghetti", "package", "1 lb box", 1, "lb", 1.49, False),
        ("Fettuccine", "package", "1 lb box", 1, "lb", 1.79, False),
        ("Penne", "package", "1 lb box", 1, "lb", 1.49, False),
        ("Ziti", "package", "1 lb box", 1, "lb", 1.49, False),
        ("Elbow macaroni", "package", "1 lb box", 1, "lb", 1.29, False),
        ("Egg noodles", "package", "12 oz bag", 12, "oz", 2.49, False),
        ("Rice noodles", "package", "14 oz package", 14, "oz", 3.49, False),
        ("White rice", "package", "2 lb bag (about 4½ cups)", 4.5, "cup", 2.79, False),
        ("Brown rice", "package", "2 lb bag (about 4½ cups)", 4.5, "cup", 3.29, False),
        ("Quinoa", "package", "12 oz bag (about 2 cups)", 2, "cup", 4.49, False),
        ("Red lentils", "package", "1 lb bag (about 2¼ cups)", 2.25, "cup", 2.49, False),
    ("Brown lentils", "package", "1 lb bag (about 2¼ cups)", 2.25, "cup", 1.99, False),
    ("Lasagna noodles", "package", "1 lb box (about 18 noodles)", 18, "", 2.29, False),
        ("Rolled oats", "package", "18 oz canister (about 6 cups)", 6, "cup", 3.99, False),
        ("Granola", "package", "12 oz bag (about 3 cups)", 3, "cup", 4.49, False),
        ("Breadcrumbs", "package", "15 oz canister (about 4 cups)", 4, "cup", 2.49, False),
        ("Croutons", "package", "5 oz bag (about 2½ cups)", 2.5, "cup", 2.29, False),
    ],
    "Canned & Jarred": [
        ("Crushed tomatoes", "package", "28 oz can", 1, "can", 2.29, False),
        ("Diced tomatoes", "package", "14.5 oz can", 1, "can", 1.29, False),
        ("Tomato sauce", "package", "15 oz can", 1, "can", 1.09, False),
        ("Kidney beans", "package", "15 oz can", 1, "can", 1.09, False),
        ("Black beans", "package", "15 oz can", 1, "can", 1.09, False),
        ("Chickpeas", "package", "15 oz can", 1, "can", 1.19, False),
    ("Pinto beans", "package", "15 oz can", 1, "can", 1.09, False),
        ("Refried beans", "package", "16 oz can", 1, "can", 1.79, False),
        # Jars and cartons only last a week or so once opened.
        ("Marinara sauce", "package", "24 oz jar (about 3 cups)", 3, "cup", 3.49, True),
        ("Basil pesto", "package", "6 oz jar", 1, "jar", 3.99, True),
        ("Chicken broth", "package", "32 oz carton (4 cups)", 4, "cup", 2.49, True),
        ("Vegetable broth", "package", "32 oz carton (4 cups)", 4, "cup", 2.49, True),
        ("Light coconut milk", "package", "13.5 oz can", 1, "can", 2.29, False),
        ("Green curry paste", "package", "4 oz jar (about 8 tbsp)", 8, "tbsp", 3.49, False),
        ("Canned tuna", "package", "5 oz can", 1, "can", 1.29, False),
        ("Salsa", "package", "16 oz jar (2 cups)", 2, "cup", 3.29, True),
    ],
    "Condiments & Sauces": [
        ("Soy sauce", "package", "15 oz bottle (about 30 tbsp)", 30, "tbsp", 2.99, False),
        ("Fish sauce", "package", "7 oz bottle (about 14 tbsp)", 14, "tbsp", 3.49, False),
        ("Teriyaki sauce", "package", "10 oz bottle (about 1¼ cups)", 1.25, "cup", 3.29, False),
        ("Honey", "package", "12 oz bottle (about 1 cup)", 1, "cup", 4.49, False),
        ("Maple syrup", "package", "12 oz bottle (1½ cups)", 1.5, "cup", 7.99, False),
        ("BBQ sauce", "package", "18 oz bottle (about 1½ cups)", 1.5, "cup", 2.49, False),
        ("Ketchup", "package", "20 oz bottle (about 2 cups)", 2, "cup", 2.79, False),
        ("Yellow mustard", "package", "8 oz bottle (1 cup)", 1, "cup", 1.29, False),
        ("Mayonnaise", "package", "15 oz jar (about 1¾ cups)", 1.75, "cup", 3.49, False),
        ("Worcestershire sauce", "package", "10 oz bottle (about 1¼ cups)", 1.25, "cup", 2.99, False),
        ("Caesar dressing", "package", "12 oz bottle (1½ cups)", 1.5, "cup", 3.49, False),
        ("Sesame oil", "package", "5 oz bottle (about 10 tbsp)", 10, "tbsp", 3.99, False),
    ("Peanut butter", "package", "16 oz jar (about 28 tbsp)", 28, "tbsp", 2.99, False),
    ],
    "Spices & Baking": [
        ("Garlic powder", "package", "3 oz jar (about 10 tbsp)", 10, "tbsp", 1.99, False),
        ("Paprika", "package", "2.5 oz jar (about 10 tbsp)", 10, "tbsp", 1.99, False),
        ("Chili powder", "package", "2.5 oz jar (about 10 tbsp)", 10, "tbsp", 1.99, False),
        ("Ground cumin", "package", "2 oz jar (about 9 tbsp)", 9, "tbsp", 2.49, False),
        ("Italian seasoning", "package", "1 oz jar (about 8 tbsp)", 8, "tbsp", 1.99, False),
        ("Dried oregano", "package", "1 oz jar (about 8 tbsp)", 8, "tbsp", 1.99, False),
        ("Dried thyme", "package", "0.75 oz jar (about 6 tbsp)", 6, "tbsp", 2.49, False),
        ("Ground cinnamon", "package", "2.5 oz jar (about 10 tbsp)", 10, "tbsp", 1.99, False),
        ("Ground turmeric", "package", "2 oz jar (about 9 tbsp)", 9, "tbsp", 2.99, False),
        ("Garam masala", "package", "2 oz jar (about 9 tbsp)", 9, "tbsp", 3.99, False),
        ("Jerk seasoning", "package", "2.5 oz jar (about 10 tbsp)", 10, "tbsp", 2.99, False),
        ("Red pepper flakes", "package", "1.5 oz jar (about 8 tbsp)", 8, "tbsp", 1.99, False),
        ("Taco seasoning", "package", "1 oz packet", 1, "packet", 0.99, False),
        ("Vanilla extract", "package", "2 oz bottle (about 4 tbsp)", 4, "tbsp", 4.99, False),
        ("Brown sugar", "package", "2 lb bag (about 4½ cups)", 4.5, "cup", 2.49, False),
        ("Cornstarch", "package", "16 oz box (about 3½ cups)", 3.5, "cup", 1.99, False),
        ("Chocolate chips", "package", "12 oz bag (2 cups)", 2, "cup", 3.49, False),
        ("Cocoa powder", "package", "8 oz can (about 2½ cups)", 2.5, "cup", 3.99, False),
        ("Chopped peanuts", "package", "8 oz bag (about 1½ cups)", 1.5, "cup", 3.49, False),
    ],
    "Frozen": [
        ("Frozen peas and carrots", "package", "12 oz bag (about 2½ cups)", 2.5, "cup", 1.49, False),
        ("Frozen corn", "package", "12 oz bag (about 2½ cups)", 2.5, "cup", 1.49, False),
    ("Frozen chopped spinach", "package", "10 oz box", 10, "oz", 1.79, False),
    ],
    # Most kitchens already have these; the shopping list assumes you do unless you say otherwise.
    "Pantry Staples": [
        ("Salt", "package", "26 oz canister (about 2½ cups)", 2.5, "cup", 1.29, False),
        ("Black pepper", "package", "3 oz jar (about 10 tbsp)", 10, "tbsp", 3.49, False),
        ("Olive oil", "package", "17 oz bottle (about 2 cups)", 2, "cup", 6.99, False),
        ("Vegetable oil", "package", "48 oz bottle (6 cups)", 6, "cup", 3.99, False),
        ("All-purpose flour", "package", "5 lb bag (about 18 cups)", 18, "cup", 3.49, False),
        ("Granulated sugar", "package", "4 lb bag (about 9 cups)", 9, "cup", 3.49, False),
        ("Baking soda", "package", "1 lb box (about 3 cups)", 3, "cup", 1.29, False),
        ("Baking powder", "package", "8 oz can (about 1½ cups)", 1.5, "cup", 2.49, False),
    ],
}
AISLE_OF = {item[0]: aisle for aisle, items in CATALOG.items() for item in items}
PACKAGE_OF = {item[0]: item for items in CATALOG.values() for item in items}

UNITS = {"", "cup", "tbsp", "tsp", "lb", "oz", "clove", "can", "jar", "slice", "pinch", "head",
         "bunch", "stalk", "packet", "carton", "pint"}

CATEGORIES = ["Breakfast", "Chicken", "Beef & Pork", "Seafood", "Pasta", "Vegetarian", "Desserts"]

# Anything not listed here is "American".
CUISINE = {
    "beef-tacos": "Mexican", "chicken-quesadillas": "Mexican", "chicken-fajitas": "Mexican",
    "bean-burritos": "Mexican", "burrito-bowls": "Mexican", "fish-tacos": "Mexican",
    "spaghetti-meat-sauce": "Italian", "chicken-alfredo": "Italian", "baked-ziti": "Italian",
    "pesto-pasta": "Italian", "minestrone": "Italian",
    "chicken-stir-fry": "Chinese", "beef-and-broccoli": "Chinese", "egg-fried-rice": "Chinese",
    "kung-pao-chicken": "Chinese",
    "tikka-masala": "Indian", "chana-masala": "Indian", "red-lentil-dal": "Indian",
    "pad-thai": "Thai", "green-curry": "Thai",
    "souvlaki": "Greek", "greek-salad": "Greek",
    "teriyaki-salmon": "Japanese", "korean-beef-bowls": "Korean",
    "jerk-chicken": "Caribbean", "shakshuka": "Middle Eastern", "grilled-fish": "Mediterranean",
    "black-bean-tacos": "Mexican", "spinach-mushroom-quesadillas": "Mexican",
    "pasta-arrabbiata": "Italian", "vegetable-lasagna": "Italian", "eggplant-parmesan": "Italian",
    "peanut-noodles": "Chinese", "teriyaki-tofu": "Japanese",
    "aloo-gobi": "Indian", "coconut-chickpea-curry": "Indian", "palak-paneer": "Indian",
    "lentil-soup": "Mediterranean", "hummus-veggie-wraps": "Mediterranean",
}

TO_TASTE = None
recipes = []


def recipe(id, name, emoji, category, minutes, difficulty, servings, nutrition, ingredients, steps):
    calories, protein, carbs, fat = nutrition
    from_macros = 4 * protein + 4 * carbs + 9 * fat
    assert abs(from_macros - calories) <= 0.12 * calories, f"{id}: {calories} cal doesn't match macros ({from_macros})"
    recipes.append({
        "id": id,
        "name": name,
        "emoji": emoji,
        "category": category,
        "cuisine": CUISINE.get(id, "American"),
        "minutes": minutes,
        "difficulty": difficulty,
        "servings": servings,
        "nutrition": {"calories": calories, "protein": protein, "carbs": carbs, "fat": fat},
        "ingredients": [
            {"name": n, "amount": a, "unit": u, "note": note, "aisle": AISLE_OF.get(n, "?"),
             "isStaple": AISLE_OF.get(n) == "Pantry Staples"}
            for (a, u, n, note) in ingredients
        ],
        "steps": steps,
    })


# ─── Breakfast ────────────────────────────────────────────────────────────────

recipe("pancakes", "Fluffy Pancakes", "🥞", "Breakfast", 20, "Easy", 4, (290, 8, 40, 11), [
    (1.5, "cup", "All-purpose flour", ""),
    (2, "tbsp", "Granulated sugar", ""),
    (2, "tsp", "Baking powder", ""),
    (0.5, "tsp", "Salt", ""),
    (1.25, "cup", "Milk", ""),
    (1, "", "Eggs", ""),
    (4, "tbsp", "Butter", "3 tbsp melted, plus more for the pan"),
    (0.25, "cup", "Maple syrup", "for serving"),
], [
    "Whisk the flour, sugar, baking powder and salt in a large bowl.",
    "In another bowl, whisk the milk, egg and 3 tbsp melted butter.",
    "Pour the wet mix into the dry mix and stir until just combined. A few lumps are fine.",
    "Heat a nonstick pan over medium heat and grease it lightly with butter.",
    "Pour about 1/4 cup of batter per pancake. Cook until bubbles form on top, about 2 minutes.",
    "Flip and cook 1 to 2 minutes more until golden. Serve warm with maple syrup.",
])

recipe("french-toast", "French Toast", "🍞", "Breakfast", 15, "Easy", 2, (380, 14, 48, 14), [
    (4, "slice", "Sandwich bread", "thick-sliced works best"),
    (2, "", "Eggs", ""),
    (0.5, "cup", "Milk", ""),
    (0.5, "tsp", "Ground cinnamon", ""),
    (1, "tsp", "Vanilla extract", ""),
    (1, "tbsp", "Butter", ""),
    (0.25, "cup", "Maple syrup", "for serving"),
], [
    "Whisk the eggs, milk, cinnamon and vanilla in a shallow dish.",
    "Melt the butter in a large pan over medium heat.",
    "Dip each slice of bread in the egg mix for a few seconds per side.",
    "Cook the slices 2 to 3 minutes per side until golden brown.",
    "Serve warm with maple syrup.",
])

recipe("scrambled-eggs", "Scrambled Eggs & Toast", "🍳", "Breakfast", 10, "Easy", 2, (330, 17, 26, 17), [
    (4, "", "Eggs", ""),
    (2, "tbsp", "Milk", ""),
    (1, "tbsp", "Butter", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
    (4, "slice", "Sandwich bread", "toasted"),
], [
    "Whisk the eggs, milk and a pinch of salt in a bowl.",
    "Melt the butter in a nonstick pan over medium-low heat.",
    "Add the eggs and let them sit for 20 seconds.",
    "Gently push the eggs around with a spatula until softly set, 2 to 3 minutes.",
    "Take the pan off the heat while the eggs still look a little wet. They finish cooking on their own.",
    "Season with pepper and serve with the toast.",
])

recipe("cheese-omelette", "Spinach & Cheese Omelette", "🥚", "Breakfast", 10, "Easy", 1, (420, 26, 4, 33), [
    (3, "", "Eggs", ""),
    (1, "tbsp", "Butter", ""),
    (1, "cup", "Spinach", ""),
    (0.25, "cup", "Shredded cheddar", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Whisk the eggs with a pinch of salt and pepper.",
    "Melt the butter in a nonstick pan over medium heat. Add the spinach and stir until wilted, about 1 minute.",
    "Pour in the eggs. As the edges set, lift them with a spatula so the runny egg flows underneath.",
    "When the top is almost set, sprinkle the cheese over one half.",
    "Fold the omelette in half and slide it onto a plate.",
])

recipe("breakfast-burritos", "Breakfast Burritos", "🌯", "Breakfast", 25, "Easy", 4, (530, 27, 34, 31), [
    (0.5, "lb", "Breakfast sausage", ""),
    (1, "", "Bell pepper", "diced"),
    (6, "", "Eggs", "beaten"),
    (1, "tbsp", "Butter", ""),
    (4, "", "Flour tortillas", "large, burrito size"),
    (1, "cup", "Shredded cheddar", ""),
    (0.5, "cup", "Salsa", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Brown the sausage and bell pepper in a large pan over medium-high heat, breaking up the sausage, about 6 minutes. Move to a plate.",
    "Lower the heat to medium-low and melt the butter in the same pan.",
    "Add the eggs with a pinch of salt and pepper and stir gently until softly scrambled.",
    "Warm the tortillas in the microwave for 20 seconds so they fold without cracking.",
    "Fill each tortilla with eggs, sausage, cheese and a spoonful of salsa.",
    "Fold in the sides, roll up tightly and serve. Wrap leftovers in foil and refrigerate.",
])

recipe("overnight-oats", "Overnight Oats", "🥣", "Breakfast", 5, "Easy", 2, (330, 14, 55, 6), [
    (1, "cup", "Rolled oats", ""),
    (1, "cup", "Milk", ""),
    (0.5, "cup", "Plain Greek yogurt", ""),
    (2, "tbsp", "Honey", ""),
    (1, "cup", "Mixed berries", ""),
], [
    "Stir the oats, milk, yogurt and honey together in a jar or bowl.",
    "Cover and refrigerate overnight, or at least 4 hours.",
    "Stir, top with berries and eat cold.",
])

recipe("avocado-toast", "Avocado Toast with Egg", "🥑", "Breakfast", 10, "Easy", 2, (310, 11, 21, 21), [
    (1, "", "Avocado", "ripe"),
    (2, "slice", "Sandwich bread", ""),
    (2, "", "Eggs", ""),
    (0.5, "", "Lemon", ""),
    (1, "tsp", "Olive oil", ""),
    (1, "pinch", "Red pepper flakes", ""),
    (TO_TASTE, "", "Salt", "to taste"),
], [
    "Toast the bread.",
    "Mash the avocado with a squeeze of lemon and a pinch of salt.",
    "Heat the oil in a nonstick pan over medium heat and fry the eggs until the whites are set, 2 to 3 minutes.",
    "Spread the avocado on the toast, top each slice with an egg and sprinkle with red pepper flakes.",
])

# ─── Chicken ──────────────────────────────────────────────────────────────────

recipe("sheet-pan-chicken", "Sheet-Pan Chicken & Veggies", "🍗", "Chicken", 40, "Easy", 4, (430, 33, 24, 22), [
    (1.5, "lb", "Boneless chicken thighs", ""),
    (1, "lb", "Baby potatoes", "halved"),
    (1, "head", "Broccoli", "cut into florets"),
    (1, "", "Bell pepper", "cut into chunks"),
    (3, "tbsp", "Olive oil", ""),
    (1, "tsp", "Garlic powder", ""),
    (1, "tsp", "Paprika", ""),
    (1, "tsp", "Italian seasoning", ""),
    (1, "tsp", "Salt", ""),
    (0.5, "tsp", "Black pepper", ""),
], [
    "Heat the oven to 425°F.",
    "Toss the potatoes with 1 tbsp oil and a pinch of salt on a large baking sheet. Roast for 10 minutes.",
    "Mix the garlic powder, paprika, Italian seasoning, salt and pepper in a small bowl.",
    "Toss the chicken, broccoli and bell pepper with the remaining 2 tbsp oil and the spice mix.",
    "Add them to the baking sheet with the potatoes and spread everything out in one layer.",
    "Roast 20 to 25 minutes, until the chicken reaches 165°F and the potatoes are tender.",
])

recipe("chicken-stir-fry", "Chicken Stir-Fry", "🥢", "Chicken", 25, "Easy", 4, (430, 32, 50, 10), [
    (1, "lb", "Chicken breast", "cut into bite-size pieces"),
    (1, "head", "Broccoli", "cut into small florets"),
    (1, "", "Bell pepper", "sliced"),
    (3, "clove", "Garlic", "minced"),
    (0.25, "cup", "Soy sauce", ""),
    (1, "tbsp", "Honey", ""),
    (1, "tbsp", "Cornstarch", ""),
    (2, "tbsp", "Vegetable oil", ""),
    (1, "cup", "White rice", "uncooked"),
], [
    "Cook the rice according to the package directions.",
    "Whisk the soy sauce, honey, cornstarch and 1/4 cup water in a small bowl.",
    "Heat 1 tbsp oil in a large pan over high heat. Cook the chicken until browned and cooked through, 5 to 6 minutes. Move it to a plate.",
    "Add the remaining oil, then the broccoli and bell pepper. Stir-fry 3 to 4 minutes until crisp-tender.",
    "Add the garlic and cook 30 seconds.",
    "Return the chicken, pour in the sauce and stir until thick and glossy, about 1 minute. Serve over rice.",
])

recipe("chicken-quesadillas", "Chicken & Pepper Quesadillas", "🫓", "Chicken", 20, "Easy", 2, (580, 39, 38, 30), [
    (0.5, "", "Rotisserie chicken", "shredded (about 2 cups)"),
    (1, "", "Bell pepper", "thinly sliced"),
    (4, "", "Flour tortillas", "8-inch"),
    (1.5, "cup", "Shredded cheddar", ""),
    (1, "tbsp", "Butter", ""),
    (0.5, "cup", "Salsa", "for serving"),
    (0.25, "cup", "Sour cream", "for serving"),
], [
    "Pull the meat off the chicken and shred it with two forks.",
    "Melt a little butter in a large pan over medium heat and cook the pepper until soft, about 4 minutes. Move it to a plate.",
    "Sprinkle cheese over half of each tortilla, add chicken and peppers, top with more cheese and fold closed.",
    "Cook the quesadillas 2 to 3 minutes per side until golden and the cheese melts.",
    "Cut into wedges and serve with salsa and sour cream.",
])

recipe("chicken-fajitas", "Chicken Fajitas", "🫑", "Chicken", 30, "Easy", 4, (450, 40, 38, 15), [
    (1.5, "lb", "Chicken breast", "sliced into strips"),
    (2, "", "Bell pepper", "sliced"),
    (1, "", "Yellow onion", "sliced"),
    (2, "tbsp", "Vegetable oil", ""),
    (1, "tbsp", "Chili powder", ""),
    (1, "tsp", "Ground cumin", ""),
    (1, "tsp", "Garlic powder", ""),
    (1, "tsp", "Salt", ""),
    (1, "", "Lime", ""),
    (8, "", "Flour tortillas", "8-inch"),
], [
    "Toss the chicken with 1 tbsp oil, the chili powder, cumin, garlic powder and salt.",
    "Heat a large pan over medium-high heat. Cook the chicken until cooked through, 6 to 7 minutes. Move it to a plate.",
    "Add the remaining oil, the peppers and the onion. Cook until soft and charred in spots, about 6 minutes.",
    "Return the chicken to the pan and squeeze the lime over everything.",
    "Warm the tortillas and fill them with the chicken and peppers.",
])

recipe("bbq-chicken", "Baked BBQ Chicken", "🍗", "Chicken", 45, "Easy", 4, (420, 30, 18, 25), [
    (2, "lb", "Bone-in chicken thighs", ""),
    (1, "tbsp", "Olive oil", ""),
    (1, "tsp", "Garlic powder", ""),
    (1, "tsp", "Paprika", ""),
    (1, "tsp", "Salt", ""),
    (0.5, "tsp", "Black pepper", ""),
    (0.75, "cup", "BBQ sauce", ""),
], [
    "Heat the oven to 425°F and line a baking sheet with foil.",
    "Pat the chicken dry. Rub it with the oil, garlic powder, paprika, salt and pepper.",
    "Bake skin-side up for 25 minutes.",
    "Brush the chicken all over with BBQ sauce.",
    "Bake 10 to 15 minutes more, until the sauce is sticky and the chicken reaches 165°F.",
])

recipe("chicken-noodle-soup", "Chicken Noodle Soup", "🍲", "Chicken", 40, "Easy", 6, (260, 25, 22, 6), [
    (1, "tbsp", "Olive oil", ""),
    (1, "", "Yellow onion", "diced"),
    (3, "", "Carrots", "sliced"),
    (3, "stalk", "Celery", "sliced"),
    (3, "clove", "Garlic", "minced"),
    (8, "cup", "Chicken broth", ""),
    (1, "lb", "Chicken breast", ""),
    (6, "oz", "Egg noodles", ""),
    (1, "tsp", "Dried thyme", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Heat the oil in a large pot over medium heat. Cook the onion, carrots and celery until soft, about 6 minutes.",
    "Add the garlic and thyme and cook 30 seconds.",
    "Pour in the broth, add the whole chicken breasts and bring to a boil.",
    "Lower the heat and simmer until the chicken is cooked through, about 15 minutes.",
    "Take out the chicken and shred it with two forks.",
    "Add the noodles to the pot and cook according to the package, about 6 minutes.",
    "Stir the chicken back in and season with salt and pepper.",
])

recipe("chicken-caesar-salad", "Chicken Caesar Salad", "🥗", "Chicken", 25, "Easy", 2, (520, 44, 16, 31), [
    (0.75, "lb", "Chicken breast", ""),
    (1, "tbsp", "Olive oil", ""),
    (1, "head", "Romaine lettuce", "chopped"),
    (0.5, "cup", "Caesar dressing", ""),
    (1, "cup", "Croutons", ""),
    (0.33, "cup", "Grated Parmesan", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Season the chicken with salt and pepper.",
    "Heat the oil in a pan over medium-high heat. Cook the chicken 5 to 7 minutes per side, until it reaches 165°F.",
    "Let the chicken rest 5 minutes, then slice it.",
    "Toss the lettuce with the dressing, croutons and most of the Parmesan.",
    "Top with the chicken and the rest of the Parmesan.",
])

recipe("honey-garlic-chicken", "Honey Garlic Chicken", "🍯", "Chicken", 25, "Easy", 4, (470, 34, 55, 12), [
    (1.5, "lb", "Boneless chicken thighs", ""),
    (4, "clove", "Garlic", "minced"),
    (0.33, "cup", "Honey", ""),
    (0.25, "cup", "Soy sauce", ""),
    (1, "tbsp", "Vegetable oil", ""),
    (1, "cup", "White rice", "uncooked"),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Cook the rice according to the package directions.",
    "Season the chicken with salt and pepper.",
    "Heat the oil in a large pan over medium-high heat. Cook the chicken 5 to 6 minutes per side until browned and cooked through.",
    "Lower the heat to medium. Add the garlic and cook 30 seconds.",
    "Add the honey and soy sauce and simmer, turning the chicken, until the sauce thickens, 2 to 3 minutes.",
    "Serve the chicken over rice with the sauce spooned on top.",
])

# ─── Beef & Pork ──────────────────────────────────────────────────────────────

recipe("beef-tacos", "Ground Beef Tacos", "🌮", "Beef & Pork", 20, "Easy", 4, (480, 28, 26, 29), [
    (1, "lb", "Ground beef", ""),
    (1, "packet", "Taco seasoning", "1 oz"),
    (8, "", "Taco shells", ""),
    (1, "cup", "Shredded cheddar", ""),
    (0.5, "head", "Romaine lettuce", "shredded"),
    (1, "", "Tomato", "diced"),
    (0.5, "cup", "Sour cream", ""),
], [
    "Brown the beef in a large pan over medium-high heat, breaking it up, about 7 minutes. Drain the fat.",
    "Stir in the taco seasoning and 2/3 cup water. Simmer until thickened, about 5 minutes.",
    "Warm the taco shells in the oven or microwave according to the package.",
    "Fill the shells with beef and top with cheese, lettuce, tomato and sour cream.",
])

recipe("cheeseburgers", "Classic Cheeseburgers", "🍔", "Beef & Pork", 20, "Easy", 4, (620, 36, 30, 38), [
    (1.5, "lb", "Ground beef", "80/20"),
    (4, "slice", "American cheese slices", ""),
    (4, "", "Hamburger buns", ""),
    (1, "", "Tomato", "sliced"),
    (0.25, "head", "Romaine lettuce", "leaves"),
    (0.25, "cup", "Ketchup", ""),
    (1, "tsp", "Salt", ""),
    (0.5, "tsp", "Black pepper", ""),
], [
    "Divide the beef into 4 equal balls and press each into a patty slightly wider than the bun.",
    "Press a shallow dent in the center of each patty so it stays flat. Season both sides with salt and pepper.",
    "Heat a large pan or grill over medium-high heat. Cook the patties 4 minutes.",
    "Flip, add a slice of cheese to each and cook 3 to 4 minutes more for medium.",
    "Toast the buns cut-side down in the pan for 1 minute.",
    "Build the burgers with lettuce, tomato and ketchup.",
])

recipe("beef-chili", "Easy Beef Chili", "🌶️", "Beef & Pork", 45, "Easy", 6, (380, 26, 30, 17), [
    (1, "tbsp", "Vegetable oil", ""),
    (1, "lb", "Ground beef", ""),
    (1, "", "Yellow onion", "diced"),
    (3, "clove", "Garlic", "minced"),
    (2, "tbsp", "Chili powder", ""),
    (1, "tsp", "Ground cumin", ""),
    (1, "can", "Crushed tomatoes", "28 oz"),
    (2, "can", "Kidney beans", "15 oz each, drained"),
    (1, "tsp", "Salt", ""),
    (0.5, "cup", "Shredded cheddar", "for topping"),
], [
    "Heat the oil in a large pot over medium-high heat. Brown the beef and onion, about 8 minutes. Drain the fat.",
    "Add the garlic, chili powder and cumin and cook 1 minute.",
    "Stir in the tomatoes, beans, salt and 1 cup water.",
    "Bring to a boil, then lower the heat and simmer 25 minutes, stirring now and then.",
    "Taste and add more salt if needed. Serve topped with cheese.",
])

recipe("meatloaf", "Classic Meatloaf", "🥩", "Beef & Pork", 70, "Easy", 6, (450, 30, 18, 28), [
    (2, "lb", "Ground beef", ""),
    (1, "", "Yellow onion", "finely diced"),
    (2, "", "Eggs", ""),
    (0.75, "cup", "Breadcrumbs", ""),
    (0.5, "cup", "Milk", ""),
    (1, "tsp", "Garlic powder", ""),
    (1.5, "tsp", "Salt", ""),
    (0.5, "tsp", "Black pepper", ""),
    (0.5, "cup", "Ketchup", ""),
    (2, "tbsp", "Brown sugar", ""),
], [
    "Heat the oven to 375°F.",
    "Mix the beef, onion, eggs, breadcrumbs, milk, garlic powder, salt and pepper in a large bowl. Don't overmix.",
    "Shape into a loaf about 9 by 5 inches on a foil-lined baking sheet.",
    "Stir the ketchup and brown sugar together and spread half over the loaf.",
    "Bake 45 minutes. Spread on the rest of the glaze and bake 10 to 15 minutes more, until it reaches 160°F.",
    "Rest 10 minutes before slicing.",
])

recipe("sloppy-joes", "Sloppy Joes", "🥪", "Beef & Pork", 20, "Easy", 4, (450, 25, 42, 19), [
    (1, "lb", "Ground beef", ""),
    (0.5, "", "Yellow onion", "diced"),
    (0.75, "cup", "Ketchup", ""),
    (1, "tbsp", "Brown sugar", ""),
    (1, "tbsp", "Worcestershire sauce", ""),
    (1, "tsp", "Yellow mustard", ""),
    (4, "", "Hamburger buns", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Brown the beef and onion in a large pan over medium-high heat, about 8 minutes. Drain the fat.",
    "Stir in the ketchup, brown sugar, Worcestershire, mustard and 1/4 cup water.",
    "Simmer until thick, about 8 minutes. Season with salt and pepper.",
    "Spoon onto the buns and serve.",
])

recipe("pork-chops", "Garlic Butter Pork Chops", "🍖", "Beef & Pork", 20, "Easy", 2, (380, 38, 1, 24), [
    (2, "", "Boneless pork chops", "about 1 inch thick"),
    (1, "tsp", "Garlic powder", ""),
    (0.5, "tsp", "Dried thyme", ""),
    (1, "tbsp", "Olive oil", ""),
    (2, "tbsp", "Butter", ""),
    (2, "clove", "Garlic", "smashed"),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Pat the pork chops dry. Season with garlic powder, thyme, salt and pepper.",
    "Heat the oil in a pan over medium-high heat. Cook the chops 4 to 5 minutes until golden underneath.",
    "Flip, then add the butter and garlic to the pan.",
    "Spoon the melted butter over the chops as they cook, 4 to 5 minutes more, until they reach 145°F.",
    "Rest 5 minutes before serving.",
])

recipe("beef-and-broccoli", "Beef & Broccoli", "🥦", "Beef & Pork", 25, "Easy", 4, (460, 31, 50, 14), [
    (1, "lb", "Flank steak", "thinly sliced against the grain"),
    (2, "tbsp", "Cornstarch", ""),
    (1, "head", "Broccoli", "cut into florets"),
    (3, "clove", "Garlic", "minced"),
    (0.33, "cup", "Soy sauce", ""),
    (2, "tbsp", "Brown sugar", ""),
    (2, "tbsp", "Vegetable oil", ""),
    (1, "cup", "White rice", "uncooked"),
], [
    "Cook the rice according to the package directions.",
    "Toss the beef with 1 tbsp cornstarch.",
    "Whisk the soy sauce, brown sugar, the remaining cornstarch and 1/2 cup water.",
    "Heat 1 tbsp oil in a large pan over high heat. Sear the beef in one layer until browned, about 2 minutes. Move it to a plate.",
    "Add the remaining oil and the broccoli with 2 tbsp water. Cover and cook 3 minutes.",
    "Add the garlic, then the beef and sauce. Stir until thick, about 1 minute. Serve over rice.",
])

# ─── Seafood ──────────────────────────────────────────────────────────────────

recipe("baked-salmon", "Lemon Garlic Salmon & Asparagus", "🐟", "Seafood", 20, "Easy", 2, (420, 36, 8, 27), [
    (2, "", "Salmon fillets", "about 6 oz each"),
    (1, "bunch", "Asparagus", "woody ends snapped off"),
    (2, "tbsp", "Butter", "melted"),
    (2, "clove", "Garlic", "minced"),
    (1, "", "Lemon", ""),
    (1, "tbsp", "Olive oil", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Heat the oven to 400°F.",
    "Toss the asparagus with the oil, salt and pepper on a baking sheet and push it to the sides.",
    "Put the salmon in the middle and season with salt and pepper.",
    "Mix the melted butter, garlic and the juice of half the lemon. Spoon it over the salmon.",
    "Bake 12 to 15 minutes, until the salmon flakes easily with a fork.",
    "Serve with the rest of the lemon cut into wedges.",
])

recipe("garlic-butter-shrimp", "Garlic Butter Shrimp & Rice", "🍤", "Seafood", 20, "Easy", 2, (560, 48, 46, 20), [
    (1, "lb", "Shrimp", "peeled and deveined"),
    (3, "tbsp", "Butter", ""),
    (4, "clove", "Garlic", "minced"),
    (0.5, "", "Lemon", ""),
    (1, "pinch", "Red pepper flakes", ""),
    (1, "cup", "White rice", "uncooked"),
    (TO_TASTE, "", "Salt", "to taste"),
], [
    "Cook the rice according to the package directions.",
    "Pat the shrimp dry and season with salt.",
    "Melt 2 tbsp butter in a large pan over medium-high heat. Cook the shrimp 1 to 2 minutes per side until pink. Move them to a plate.",
    "Lower the heat, add the remaining butter, the garlic and the red pepper flakes. Cook 30 seconds.",
    "Return the shrimp, squeeze in the lemon and toss. Serve over rice.",
])

recipe("tuna-melt", "Tuna Melt", "🐠", "Seafood", 15, "Easy", 2, (450, 27, 26, 26), [
    (1, "can", "Canned tuna", "5 oz, drained"),
    (2, "tbsp", "Mayonnaise", ""),
    (1, "stalk", "Celery", "finely diced"),
    (4, "slice", "Sandwich bread", ""),
    (4, "slice", "Cheddar slices", ""),
    (1, "tbsp", "Butter", ""),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Mix the tuna, mayonnaise, celery and a pinch of pepper.",
    "Spread the tuna on 2 slices of bread, top with the cheese and the other bread.",
    "Butter the outsides of the sandwiches.",
    "Cook in a pan over medium-low heat, 3 to 4 minutes per side, until golden and the cheese melts.",
])

# ─── Pasta ────────────────────────────────────────────────────────────────────

recipe("spaghetti-meat-sauce", "Spaghetti with Meat Sauce", "🍝", "Pasta", 30, "Easy", 4, (630, 40, 80, 17), [
    (12, "oz", "Spaghetti", ""),
    (1, "lb", "Ground beef", "90% lean is lighter"),
    (2, "cup", "Spinach", ""),
    (1, "", "Yellow onion", "diced"),
    (3, "clove", "Garlic", "minced"),
    (3, "cup", "Marinara sauce", "one 24 oz jar"),
    (1, "tsp", "Italian seasoning", ""),
    (0.25, "cup", "Grated Parmesan", "for serving"),
    (TO_TASTE, "", "Salt", "to taste"),
], [
    "Bring a large pot of salted water to a boil.",
    "Brown the beef and onion in a large pan over medium-high heat, about 8 minutes. Drain the fat.",
    "Add the garlic and Italian seasoning and cook 30 seconds.",
    "Pour in the marinara and simmer 10 minutes. Stir in the spinach until it wilts.",
    "Meanwhile, cook the spaghetti according to the package. Drain.",
    "Serve the sauce over the spaghetti with Parmesan on top.",
])

recipe("mac-and-cheese", "Broccoli Mac & Cheese", "🧀", "Pasta", 20, "Easy", 4, (540, 24, 56, 25), [
    (8, "oz", "Elbow macaroni", ""),
    (1, "head", "Broccoli", "cut into small florets"),
    (2, "tbsp", "Butter", ""),
    (2, "tbsp", "All-purpose flour", ""),
    (2, "cup", "Milk", ""),
    (2, "cup", "Shredded cheddar", ""),
    (0.5, "tsp", "Garlic powder", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Cook the macaroni in salted water according to the package, adding the broccoli for the last 3 minutes. Drain.",
    "In the same pot, melt the butter over medium heat. Whisk in the flour and cook 1 minute.",
    "Slowly whisk in the milk. Cook, whisking, until it thickens slightly, about 4 minutes.",
    "Take the pot off the heat and stir in the cheese and garlic powder until smooth.",
    "Stir in the macaroni and broccoli and season with salt and pepper.",
])

recipe("chicken-alfredo", "Chicken & Broccoli Alfredo", "🍜", "Pasta", 30, "Easy", 4, (650, 45, 55, 28), [
    (8, "oz", "Fettuccine", ""),
    (1, "lb", "Chicken breast", "cut into bite-size pieces"),
    (1, "head", "Broccoli", "cut into small florets"),
    (2, "tbsp", "Butter", ""),
    (2, "clove", "Garlic", "minced"),
    (1, "tbsp", "All-purpose flour", ""),
    (1.5, "cup", "Milk", ""),
    (0.5, "cup", "Heavy cream", ""),
    (0.75, "cup", "Grated Parmesan", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Cook the fettuccine in salted water according to the package, adding the broccoli for the last 3 minutes. Drain.",
    "Season the chicken with salt and pepper. Melt 1 tbsp butter in a large pan over medium-high heat and cook the chicken until cooked through, 6 to 7 minutes. Move it to a plate.",
    "Melt the remaining butter over medium heat. Add the garlic and cook 30 seconds.",
    "Whisk in the flour, then slowly whisk in the milk and cream. Simmer, whisking, until slightly thick, about 3 minutes.",
    "Take the pan off the heat and stir in the Parmesan until smooth.",
    "Toss in the pasta, broccoli and chicken. Season with salt and pepper.",
])

recipe("baked-ziti", "Baked Ziti", "🍝", "Pasta", 45, "Easy", 6, (520, 25, 68, 16), [
    (1, "lb", "Ziti", "penne works too"),
    (3, "cup", "Marinara sauce", "one 24 oz jar"),
    (1, "cup", "Ricotta", ""),
    (2, "cup", "Shredded mozzarella", ""),
    (0.5, "cup", "Grated Parmesan", ""),
    (1, "tsp", "Italian seasoning", ""),
    (TO_TASTE, "", "Salt", "for the pasta water"),
], [
    "Heat the oven to 375°F.",
    "Cook the ziti in salted water for 2 minutes less than the package says. Drain.",
    "Stir the pasta with the marinara, ricotta, Italian seasoning and 1 cup mozzarella.",
    "Spread it in a 9x13-inch baking dish and top with the rest of the mozzarella and the Parmesan.",
    "Bake 20 minutes, until bubbly and the cheese is melted.",
])

recipe("pesto-pasta", "Pesto Pasta with Tomatoes", "🌿", "Pasta", 15, "Easy", 4, (560, 18, 70, 23), [
    (1, "lb", "Penne", ""),
    (1, "jar", "Basil pesto", "6 oz"),
    (1, "pint", "Cherry tomatoes", "halved"),
    (0.5, "cup", "Grated Parmesan", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Cook the penne in salted water according to the package. Save 1/2 cup of the pasta water, then drain.",
    "Toss the pasta with the pesto and a splash of pasta water until glossy.",
    "Fold in the tomatoes and Parmesan. Season with salt and pepper.",
])

# ─── Vegetarian ───────────────────────────────────────────────────────────────

recipe("grilled-cheese", "Grilled Cheese Sandwich", "🥪", "Vegetarian", 10, "Easy", 2, (440, 17, 28, 29), [
    (4, "slice", "Sandwich bread", ""),
    (4, "slice", "Cheddar slices", ""),
    (2, "tbsp", "Butter", "softened"),
], [
    "Butter one side of each slice of bread.",
    "Place 2 slices butter-side down in a pan and top each with 2 slices of cheese and another slice of bread, butter-side up.",
    "Cook over medium-low heat 3 to 4 minutes per side, until golden and the cheese melts.",
])

recipe("tomato-soup", "Creamy Tomato Soup", "🍅", "Vegetarian", 30, "Easy", 4, (210, 4, 18, 14), [
    (2, "tbsp", "Butter", ""),
    (1, "", "Yellow onion", "diced"),
    (2, "clove", "Garlic", "minced"),
    (1, "can", "Crushed tomatoes", "28 oz"),
    (2, "cup", "Vegetable broth", ""),
    (0.5, "cup", "Heavy cream", ""),
    (1, "tsp", "Granulated sugar", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Melt the butter in a pot over medium heat. Cook the onion until soft, about 6 minutes.",
    "Add the garlic and cook 30 seconds.",
    "Add the tomatoes, broth and sugar. Simmer 15 minutes.",
    "Blend until smooth with an immersion blender, or carefully in a regular blender.",
    "Stir in the cream and season with salt and pepper. Great with a grilled cheese.",
])

recipe("bean-burritos", "Bean & Cheese Burritos", "🫘", "Vegetarian", 15, "Easy", 4, (490, 20, 55, 21), [
    (1, "can", "Refried beans", "16 oz"),
    (4, "", "Flour tortillas", "large, burrito size"),
    (1.5, "cup", "Shredded cheddar", ""),
    (0.5, "cup", "Salsa", ""),
    (1, "tsp", "Chili powder", ""),
    (0.25, "cup", "Sour cream", "for serving"),
], [
    "Warm the beans with the chili powder in a small pot or the microwave, stirring until smooth.",
    "Warm the tortillas for 20 seconds so they fold easily.",
    "Spread beans down the middle of each tortilla and top with cheese and salsa.",
    "Fold in the sides and roll up.",
    "For a crisp outside, cook seam-side down in a dry pan over medium heat, 2 minutes per side. Serve with sour cream.",
])

recipe("egg-fried-rice", "Egg Fried Rice", "🍚", "Vegetarian", 20, "Easy", 3, (480, 16, 66, 17), [
    (1, "cup", "White rice", "cooked and cooled, ideally a day ahead (about 3 cups cooked)"),
    (3, "", "Eggs", "beaten"),
    (1, "cup", "Frozen peas and carrots", ""),
    (3, "", "Green onions", "sliced"),
    (2, "clove", "Garlic", "minced"),
    (3, "tbsp", "Soy sauce", ""),
    (2, "tbsp", "Vegetable oil", ""),
    (1, "tsp", "Sesame oil", ""),
], [
    "Cook the rice according to the package, spread it on a plate and let it cool completely. Day-old rice works best.",
    "Heat 1 tbsp vegetable oil in a large pan over medium-high heat. Scramble the eggs, then move them to a plate.",
    "Add the remaining oil, the peas and carrots and the garlic. Cook 2 minutes.",
    "Add the rice and press it into the pan. Cook without stirring 1 minute, then toss. Repeat for 3 to 4 minutes.",
    "Stir in the soy sauce, sesame oil, eggs and green onions.",
])

recipe("baked-potatoes", "Loaded Baked Potatoes", "🥔", "Vegetarian", 60, "Easy", 4, (430, 12, 52, 20), [
    (4, "", "Russet potatoes", "scrubbed"),
    (1, "tbsp", "Olive oil", ""),
    (4, "tbsp", "Butter", ""),
    (1, "cup", "Shredded cheddar", ""),
    (0.5, "cup", "Sour cream", ""),
    (3, "", "Green onions", "sliced"),
    (TO_TASTE, "", "Salt", "to taste"),
], [
    "Heat the oven to 425°F.",
    "Poke each potato a few times with a fork, rub with oil and sprinkle with salt.",
    "Bake directly on the oven rack for 50 to 60 minutes, until a knife slides in easily.",
    "Short on time? Microwave them 8 to 10 minutes instead, turning halfway.",
    "Split the potatoes open and fluff the insides with a fork.",
    "Top with butter, cheese, sour cream and green onions.",
])

recipe("naan-pizza", "Naan Margherita Pizza", "🍕", "Vegetarian", 15, "Easy", 2, (520, 22, 58, 22), [
    (2, "", "Naan", ""),
    (0.5, "cup", "Marinara sauce", ""),
    (1, "cup", "Shredded mozzarella", ""),
    (1, "", "Tomato", "thinly sliced"),
    (0.25, "bunch", "Fresh basil", "leaves"),
    (1, "tbsp", "Olive oil", ""),
], [
    "Heat the oven to 425°F.",
    "Place the naan on a baking sheet and spread with marinara.",
    "Top with mozzarella and tomato slices and drizzle with olive oil.",
    "Bake 8 to 10 minutes, until the cheese is bubbly.",
    "Scatter the basil leaves on top and slice.",
])

# ─── Desserts ─────────────────────────────────────────────────────────────────

recipe("chocolate-chip-cookies", "Chocolate Chip Cookies", "🍪", "Desserts", 30, "Easy", 24, (180, 2, 23, 9), [
    (1, "cup", "Butter", "2 sticks, softened"),
    (0.75, "cup", "Granulated sugar", ""),
    (0.75, "cup", "Brown sugar", "packed"),
    (2, "", "Eggs", ""),
    (2, "tsp", "Vanilla extract", ""),
    (2.25, "cup", "All-purpose flour", ""),
    (1, "tsp", "Baking soda", ""),
    (1, "tsp", "Salt", ""),
    (2, "cup", "Chocolate chips", ""),
], [
    "Heat the oven to 375°F.",
    "Beat the butter and both sugars until creamy, about 2 minutes.",
    "Beat in the eggs and vanilla.",
    "Stir in the flour, baking soda and salt until just combined, then fold in the chocolate chips.",
    "Scoop rounded tablespoons of dough 2 inches apart onto baking sheets.",
    "Bake 9 to 11 minutes, until the edges are golden. Cool 5 minutes on the sheet.",
])

recipe("banana-bread", "Banana Bread", "🍌", "Desserts", 70, "Easy", 10, (230, 3, 38, 7), [
    (3, "", "Bananas", "very ripe"),
    (0.33, "cup", "Butter", "melted"),
    (0.75, "cup", "Granulated sugar", ""),
    (1, "", "Eggs", ""),
    (1, "tsp", "Vanilla extract", ""),
    (1, "tsp", "Baking soda", ""),
    (1, "pinch", "Salt", ""),
    (1.5, "cup", "All-purpose flour", ""),
], [
    "Heat the oven to 350°F and butter a 9x5-inch loaf pan.",
    "Mash the bananas in a large bowl, then stir in the melted butter.",
    "Stir in the sugar, egg and vanilla.",
    "Sprinkle the baking soda and salt over the batter, then stir in the flour until just combined.",
    "Pour into the pan and bake 55 to 65 minutes, until a toothpick in the center comes out clean.",
    "Cool 10 minutes in the pan, then turn out to cool fully.",
])

recipe("brownies", "Fudgy Brownies", "🍫", "Desserts", 40, "Easy", 16, (150, 2, 20, 8), [
    (0.5, "cup", "Butter", "melted"),
    (1, "cup", "Granulated sugar", ""),
    (2, "", "Eggs", ""),
    (1, "tsp", "Vanilla extract", ""),
    (0.33, "cup", "Cocoa powder", "unsweetened"),
    (0.5, "cup", "All-purpose flour", ""),
    (0.25, "tsp", "Baking powder", ""),
    (0.25, "tsp", "Salt", ""),
    (0.5, "cup", "Chocolate chips", ""),
], [
    "Heat the oven to 350°F and line an 8x8-inch pan with parchment paper.",
    "Whisk the melted butter and sugar, then whisk in the eggs and vanilla.",
    "Stir in the cocoa, flour, baking powder and salt until just combined.",
    "Fold in the chocolate chips and spread the batter in the pan.",
    "Bake 20 to 25 minutes, until a toothpick comes out with a few moist crumbs.",
    "Cool completely before cutting into 16 squares.",
])

recipe("apple-crisp", "Apple Crisp", "🍎", "Desserts", 50, "Easy", 6, (330, 3, 52, 13), [
    (5, "", "Apples", "peeled and sliced"),
    (2, "tbsp", "Granulated sugar", ""),
    (1.5, "tsp", "Ground cinnamon", ""),
    (0.75, "cup", "Rolled oats", ""),
    (0.5, "cup", "All-purpose flour", ""),
    (0.5, "cup", "Brown sugar", "packed"),
    (6, "tbsp", "Butter", "cold, cubed"),
    (1, "pinch", "Salt", ""),
], [
    "Heat the oven to 350°F.",
    "Toss the apples with the sugar and 1 tsp cinnamon and spread them in an 8x8-inch baking dish.",
    "Mix the oats, flour, brown sugar, the remaining cinnamon and the salt.",
    "Rub in the butter with your fingers until the mix looks like coarse crumbs.",
    "Sprinkle the topping over the apples.",
    "Bake 35 to 40 minutes, until golden and bubbly. Serve warm.",
])


# ─── Healthy & world favorites ────────────────────────────────────────────────

recipe("yogurt-parfait", "Greek Yogurt Berry Parfait", "🍓", "Breakfast", 5, "Easy", 1, (440, 23, 52, 16), [
    (1, "cup", "Plain Greek yogurt", ""),
    (0.5, "cup", "Mixed berries", ""),
    (0.25, "cup", "Granola", ""),
    (1, "tbsp", "Honey", ""),
], [
    "Spoon half the yogurt into a glass or bowl.",
    "Add half the berries and half the granola.",
    "Repeat the layers and drizzle with honey.",
])

recipe("egg-muffins", "Veggie Egg Muffins", "🧁", "Breakfast", 30, "Easy", 6, (170, 14, 3, 11), [
    (10, "", "Eggs", ""),
    (0.25, "cup", "Milk", ""),
    (1, "cup", "Spinach", "chopped"),
    (1, "", "Bell pepper", "finely diced"),
    (3, "", "Green onions", "sliced"),
    (0.5, "cup", "Shredded cheddar", ""),
    (1, "tsp", "Olive oil", "for the pan"),
    (0.5, "tsp", "Salt", ""),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Heat the oven to 350°F and grease a 12-cup muffin pan with the oil.",
    "Whisk the eggs, milk, salt and pepper in a large bowl.",
    "Divide the spinach, bell pepper, green onions and cheese among the muffin cups.",
    "Pour the egg mix over the vegetables, filling each cup about three-quarters full.",
    "Bake 20 to 22 minutes, until the centers are set.",
    "Cool 5 minutes before removing. They keep 4 days in the fridge; reheat 30 seconds in the microwave.",
])

recipe("shakshuka", "Shakshuka", "🍳", "Breakfast", 25, "Easy", 2, (550, 26, 63, 22), [
    (1, "tbsp", "Olive oil", ""),
    (1, "", "Yellow onion", "diced"),
    (1, "", "Bell pepper", "diced"),
    (2, "clove", "Garlic", "minced"),
    (1, "tsp", "Ground cumin", ""),
    (1, "tsp", "Paprika", ""),
    (1, "can", "Crushed tomatoes", "28 oz"),
    (4, "", "Eggs", ""),
    (0.25, "cup", "Feta cheese", "crumbled"),
    (2, "", "Pita bread", "warmed, for dipping"),
    (TO_TASTE, "", "Salt", "to taste"),
], [
    "Heat the oil in a large pan over medium heat. Cook the onion and bell pepper until soft, about 6 minutes.",
    "Add the garlic, cumin and paprika and cook 30 seconds.",
    "Pour in the tomatoes, season with salt and simmer until slightly thick, about 8 minutes.",
    "Make 4 wells in the sauce with a spoon and crack an egg into each.",
    "Cover and cook on low until the whites are set but the yolks are still soft, 5 to 7 minutes.",
    "Sprinkle with feta and serve with warm pita.",
])

recipe("tikka-masala", "Chicken Tikka Masala", "🍛", "Chicken", 40, "Easy", 4, (620, 42, 47, 29), [
    (1.5, "lb", "Boneless chicken thighs", "cut into bite-size pieces"),
    (0.5, "cup", "Plain Greek yogurt", ""),
    (1, "tbsp", "Garam masala", ""),
    (1, "tsp", "Ground turmeric", ""),
    (1, "tbsp", "Vegetable oil", ""),
    (1, "", "Yellow onion", "diced"),
    (4, "clove", "Garlic", "minced"),
    (1, "tbsp", "Ginger", "grated"),
    (1, "can", "Tomato sauce", "15 oz"),
    (0.5, "cup", "Heavy cream", ""),
    (1, "cup", "White rice", "uncooked"),
    (1, "tsp", "Salt", ""),
], [
    "Mix the chicken with the yogurt, half the garam masala, the turmeric and the salt. Let it sit 10 minutes (or up to a day in the fridge).",
    "Cook the rice according to the package directions.",
    "Heat the oil in a large pan over medium-high heat. Cook the chicken until browned, about 6 minutes. Move it to a plate.",
    "Lower the heat to medium. Cook the onion until soft, about 5 minutes, then add the garlic, ginger and remaining garam masala for 1 minute.",
    "Stir in the tomato sauce and simmer 5 minutes.",
    "Add the cream and chicken and simmer until the chicken is cooked through, about 5 minutes. Serve over rice.",
])

recipe("souvlaki", "Greek Chicken Souvlaki with Tzatziki", "🥙", "Chicken", 30, "Easy", 4, (490, 51, 40, 14), [
    (1.5, "lb", "Chicken breast", "cut into 1-inch pieces"),
    (2, "tbsp", "Olive oil", ""),
    (1, "", "Lemon", ""),
    (3, "clove", "Garlic", "minced"),
    (2, "tsp", "Dried oregano", ""),
    (1, "cup", "Plain Greek yogurt", ""),
    (1, "", "Cucumber", ""),
    (4, "", "Pita bread", ""),
    (1, "", "Tomato", "sliced"),
    (0.5, "", "Red onion", "thinly sliced"),
    (1, "tsp", "Salt", ""),
], [
    "Toss the chicken with the oil, the juice of half the lemon, two-thirds of the garlic, the oregano and the salt.",
    "Grate half the cucumber, squeeze out the water and stir it into the yogurt with the remaining garlic and a squeeze of lemon. That's your tzatziki.",
    "Thread the chicken onto skewers, or skip them and cook the pieces loose.",
    "Cook on a grill pan or outdoor grill over medium-high heat, turning, until cooked through, 10 to 12 minutes.",
    "Warm the pitas for a minute on the grill.",
    "Fill the pitas with chicken, tomato, red onion, sliced cucumber and tzatziki.",
])

recipe("burrito-bowls", "Chicken Burrito Bowls", "🫔", "Chicken", 35, "Easy", 4, (610, 52, 67, 15), [
    (1.5, "lb", "Chicken breast", ""),
    (1, "tbsp", "Chili powder", ""),
    (1, "tsp", "Ground cumin", ""),
    (1, "tbsp", "Olive oil", ""),
    (1, "cup", "Brown rice", "uncooked"),
    (1, "can", "Black beans", "15 oz, rinsed"),
    (1, "cup", "Frozen corn", ""),
    (1, "cup", "Salsa", ""),
    (1, "", "Avocado", "sliced"),
    (1, "", "Lime", ""),
    (0.5, "head", "Romaine lettuce", "shredded"),
    (1, "tsp", "Salt", ""),
], [
    "Cook the brown rice according to the package. Stir in the juice of half the lime.",
    "Rub the chicken with the chili powder, cumin and salt.",
    "Heat the oil in a pan over medium-high heat. Cook the chicken 6 to 7 minutes per side, until it reaches 165°F. Rest 5 minutes, then slice.",
    "Warm the beans and corn together in a small pot or the microwave.",
    "Fill bowls with rice, lettuce, beans and corn, and chicken.",
    "Top with salsa and avocado, with lime wedges on the side.",
])

recipe("green-curry", "Thai Green Curry", "🥥", "Chicken", 30, "Easy", 4, (470, 27, 45, 20), [
    (1, "lb", "Boneless chicken thighs", "thinly sliced"),
    (3, "tbsp", "Green curry paste", ""),
    (1, "can", "Light coconut milk", "13.5 oz"),
    (1, "", "Bell pepper", "sliced"),
    (1, "", "Zucchini", "halved and sliced"),
    (1, "tbsp", "Fish sauce", ""),
    (1, "tsp", "Brown sugar", ""),
    (0.25, "bunch", "Fresh basil", "leaves"),
    (1, "tbsp", "Vegetable oil", ""),
    (1, "cup", "White rice", "uncooked"),
], [
    "Cook the rice according to the package directions.",
    "Heat the oil in a large pan over medium heat. Stir the curry paste in the oil for 1 minute until fragrant.",
    "Add the chicken and cook, stirring, until no longer pink outside, about 4 minutes.",
    "Pour in the coconut milk and 1/2 cup water and bring to a simmer.",
    "Add the bell pepper and zucchini and simmer until tender and the chicken is cooked through, about 8 minutes.",
    "Stir in the fish sauce, brown sugar and basil. Serve over rice.",
])

recipe("jerk-chicken", "Jamaican Jerk Chicken with Rice & Beans", "🌴", "Chicken", 45, "Easy", 4, (600, 38, 55, 25), [
    (2, "lb", "Bone-in chicken thighs", ""),
    (2, "tbsp", "Jerk seasoning", ""),
    (1, "tbsp", "Brown sugar", ""),
    (1, "tbsp", "Olive oil", ""),
    (1, "", "Lime", ""),
    (1, "cup", "White rice", "uncooked"),
    (1, "can", "Kidney beans", "15 oz, rinsed"),
    (3, "", "Green onions", "sliced"),
    (TO_TASTE, "", "Salt", "to taste"),
], [
    "Heat the oven to 425°F and line a baking sheet with foil.",
    "Rub the chicken with the oil, jerk seasoning, brown sugar and the juice of half the lime.",
    "Bake skin-side up for 35 to 40 minutes, until the skin is crisp and the chicken reaches 175°F.",
    "Meanwhile, cook the rice according to the package. Stir in the beans and most of the green onions, then season with salt.",
    "Serve the chicken over the rice and beans with the rest of the green onions and lime wedges.",
])

recipe("kung-pao-chicken", "Kung Pao Chicken", "🥜", "Chicken", 25, "Easy", 4, (500, 40, 47, 17), [
    (1.25, "lb", "Chicken breast", "cut into bite-size pieces"),
    (1, "tbsp", "Cornstarch", ""),
    (3, "tbsp", "Soy sauce", ""),
    (1, "tbsp", "Brown sugar", ""),
    (3, "clove", "Garlic", "minced"),
    (1, "", "Bell pepper", "diced"),
    (0.33, "cup", "Chopped peanuts", ""),
    (0.5, "tsp", "Red pepper flakes", ""),
    (3, "", "Green onions", "sliced"),
    (2, "tbsp", "Vegetable oil", ""),
    (1, "cup", "White rice", "uncooked"),
], [
    "Cook the rice according to the package directions.",
    "Toss the chicken with the cornstarch. Whisk the soy sauce, brown sugar and 1/4 cup water in a small bowl.",
    "Heat the oil in a large pan over high heat. Cook the chicken until golden and cooked through, 5 to 6 minutes.",
    "Add the bell pepper, garlic and red pepper flakes and stir-fry 2 minutes.",
    "Pour in the sauce and stir until glossy, about 1 minute.",
    "Toss in the peanuts and green onions. Serve over rice.",
])

recipe("korean-beef-bowls", "Korean Beef Bowls", "🍚", "Beef & Pork", 20, "Easy", 4, (480, 29, 53, 17), [
    (1, "lb", "Ground beef", "90% lean"),
    (3, "clove", "Garlic", "minced"),
    (1, "tbsp", "Ginger", "grated"),
    (0.25, "cup", "Soy sauce", ""),
    (2, "tbsp", "Brown sugar", ""),
    (1, "tsp", "Sesame oil", ""),
    (1, "pinch", "Red pepper flakes", ""),
    (3, "", "Green onions", "sliced"),
    (1, "head", "Broccoli", "cut into florets"),
    (1, "cup", "White rice", "uncooked"),
], [
    "Cook the rice according to the package directions.",
    "Steam or microwave the broccoli with a splash of water until tender, about 4 minutes.",
    "Brown the beef in a large pan over medium-high heat, breaking it up, about 6 minutes. Drain the fat.",
    "Add the garlic and ginger and cook 1 minute.",
    "Stir in the soy sauce, brown sugar, sesame oil and red pepper flakes and simmer 2 minutes.",
    "Serve the beef over rice with the broccoli and green onions.",
])

recipe("grilled-fish", "Grilled Lemon Herb Fish", "🍋", "Seafood", 20, "Easy", 2, (440, 38, 36, 16), [
    (2, "", "White fish fillets", "cod or tilapia"),
    (2, "", "Zucchini", "sliced lengthwise"),
    (1.5, "tbsp", "Olive oil", ""),
    (1, "", "Lemon", ""),
    (2, "clove", "Garlic", "minced"),
    (1, "tsp", "Dried oregano", ""),
    (0.5, "tsp", "Paprika", ""),
    (0.5, "cup", "Quinoa", "uncooked"),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Cook the quinoa according to the package directions.",
    "Mix the oil, the juice of half the lemon, the garlic, oregano and paprika.",
    "Brush the fish and zucchini with the mix and season with salt and pepper.",
    "Heat a grill pan or outdoor grill over medium-high heat and oil it well.",
    "Grill the zucchini 3 minutes per side. Grill the fish 3 to 4 minutes per side, until it flakes easily.",
    "Serve over quinoa with the rest of the lemon cut into wedges.",
])

recipe("teriyaki-salmon", "Teriyaki Salmon Bowls", "🍣", "Seafood", 25, "Easy", 2, (590, 43, 52, 23), [
    (2, "", "Salmon fillets", "about 6 oz each"),
    (0.25, "cup", "Teriyaki sauce", ""),
    (0.5, "cup", "Brown rice", "uncooked"),
    (0.5, "head", "Broccoli", "cut into florets"),
    (1, "", "Cucumber", "sliced"),
    (2, "", "Green onions", "sliced"),
], [
    "Cook the brown rice according to the package directions.",
    "Heat the oven to 400°F. Put the salmon and broccoli on a lined baking sheet.",
    "Brush the salmon with half the teriyaki sauce.",
    "Bake 12 to 15 minutes, until the salmon flakes easily.",
    "Fill bowls with rice, salmon, broccoli and cucumber.",
    "Drizzle with the remaining teriyaki sauce and top with green onions.",
])

recipe("fish-tacos", "Fish Tacos with Lime Slaw", "🐠", "Seafood", 25, "Easy", 4, (480, 40, 51, 13), [
    (4, "", "White fish fillets", "cod or tilapia"),
    (2, "tsp", "Chili powder", ""),
    (1, "tsp", "Ground cumin", ""),
    (1, "tbsp", "Olive oil", ""),
    (8, "", "Flour tortillas", "8-inch"),
    (2, "cup", "Coleslaw mix", ""),
    (2, "", "Lime", ""),
    (0.5, "cup", "Plain Greek yogurt", ""),
    (0.25, "bunch", "Fresh cilantro", "chopped"),
    (TO_TASTE, "", "Salt", "to taste"),
], [
    "Toss the slaw with the juice of 1 lime and a pinch of salt.",
    "Stir the yogurt with a squeeze of lime and a pinch of salt for the sauce.",
    "Season the fish with the chili powder, cumin and salt.",
    "Heat the oil in a large pan over medium-high heat. Cook the fish 3 minutes per side, until it flakes. Break into chunks.",
    "Warm the tortillas and fill with fish, slaw, sauce and cilantro. Serve with lime wedges.",
])

recipe("pad-thai", "Shrimp Pad Thai", "🍤", "Seafood", 30, "Medium", 4, (510, 31, 59, 16), [
    (8, "oz", "Rice noodles", ""),
    (1, "lb", "Shrimp", "peeled and deveined"),
    (2, "", "Eggs", "beaten"),
    (3, "tbsp", "Fish sauce", ""),
    (3, "tbsp", "Brown sugar", ""),
    (2, "", "Lime", ""),
    (3, "clove", "Garlic", "minced"),
    (4, "", "Green onions", "cut into 1-inch pieces"),
    (0.33, "cup", "Chopped peanuts", ""),
    (2, "tbsp", "Vegetable oil", ""),
], [
    "Soak the noodles in hot water according to the package until bendy but still firm. Drain.",
    "Whisk the fish sauce, brown sugar and the juice of 1 lime.",
    "Heat 1 tbsp oil in a large pan over medium-high heat. Cook the shrimp until pink, about 2 minutes. Move to a plate.",
    "Add the remaining oil and the garlic, then push it aside and scramble the eggs.",
    "Add the noodles and sauce and toss until the noodles soak up the sauce, 2 to 3 minutes.",
    "Toss in the shrimp and green onions. Top with peanuts and serve with lime wedges.",
])

recipe("chana-masala", "Chana Masala", "🥘", "Vegetarian", 30, "Easy", 4, (440, 14, 73, 10), [
    (2, "tbsp", "Vegetable oil", ""),
    (1, "", "Yellow onion", "diced"),
    (3, "clove", "Garlic", "minced"),
    (1, "tbsp", "Ginger", "grated"),
    (2, "tsp", "Garam masala", ""),
    (1, "tsp", "Ground cumin", ""),
    (0.5, "tsp", "Ground turmeric", ""),
    (1, "can", "Diced tomatoes", "14.5 oz"),
    (2, "can", "Chickpeas", "15 oz each, drained"),
    (0.25, "bunch", "Fresh cilantro", "chopped"),
    (1, "cup", "White rice", "uncooked"),
    (1, "tsp", "Salt", ""),
], [
    "Cook the rice according to the package directions.",
    "Heat the oil in a large pan over medium heat. Cook the onion until golden, about 7 minutes.",
    "Add the garlic, ginger, garam masala, cumin and turmeric and cook 1 minute.",
    "Stir in the tomatoes, chickpeas, salt and 1/2 cup water.",
    "Simmer 15 minutes, mashing a few chickpeas to thicken the sauce.",
    "Top with cilantro and serve over rice.",
])

recipe("red-lentil-dal", "Red Lentil Dal", "🫛", "Vegetarian", 30, "Easy", 4, (430, 16, 74, 8), [
    (1, "cup", "Red lentils", "rinsed"),
    (1, "", "Yellow onion", "diced"),
    (3, "clove", "Garlic", "minced"),
    (1, "tbsp", "Ginger", "grated"),
    (1, "tsp", "Ground turmeric", ""),
    (1, "tsp", "Ground cumin", ""),
    (1, "can", "Diced tomatoes", "14.5 oz"),
    (1, "tbsp", "Butter", ""),
    (1, "tbsp", "Vegetable oil", ""),
    (0.25, "bunch", "Fresh cilantro", "chopped"),
    (1, "cup", "White rice", "uncooked"),
    (1, "tsp", "Salt", ""),
], [
    "Cook the rice according to the package directions.",
    "Heat the oil in a pot over medium heat. Cook the onion until soft, about 6 minutes.",
    "Add the garlic, ginger, turmeric and cumin and cook 1 minute.",
    "Add the lentils, tomatoes, salt and 3 cups water. Bring to a boil.",
    "Simmer, stirring now and then, until the lentils break down and turn creamy, about 20 minutes.",
    "Stir in the butter, top with cilantro and serve over rice.",
])

recipe("greek-salad", "Greek Salad with Chickpeas", "🫒", "Vegetarian", 15, "Easy", 2, (470, 17, 44, 25), [
    (1, "", "Cucumber", "chopped"),
    (2, "", "Tomato", "chopped"),
    (1, "", "Bell pepper", "chopped"),
    (0.25, "", "Red onion", "thinly sliced"),
    (1, "can", "Chickpeas", "15 oz, drained"),
    (0.5, "cup", "Feta cheese", "crumbled"),
    (2, "tbsp", "Olive oil", ""),
    (1, "", "Lemon", ""),
    (1, "tsp", "Dried oregano", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Whisk the oil, the juice of the lemon, the oregano, salt and pepper in a large bowl.",
    "Add the cucumber, tomatoes, bell pepper, red onion and chickpeas and toss.",
    "Top with feta. It keeps well for lunch the next day.",
])

recipe("minestrone", "Minestrone Soup", "🥕", "Vegetarian", 40, "Easy", 6, (210, 8, 34, 5), [
    (2, "tbsp", "Olive oil", ""),
    (1, "", "Yellow onion", "diced"),
    (2, "", "Carrots", "diced"),
    (2, "stalk", "Celery", "diced"),
    (3, "clove", "Garlic", "minced"),
    (1, "", "Zucchini", "diced"),
    (1, "can", "Diced tomatoes", "14.5 oz"),
    (6, "cup", "Vegetable broth", ""),
    (1, "can", "Kidney beans", "15 oz, drained"),
    (4, "oz", "Elbow macaroni", ""),
    (1, "tsp", "Italian seasoning", ""),
    (TO_TASTE, "", "Salt", "to taste"),
], [
    "Heat the oil in a large pot over medium heat. Cook the onion, carrots and celery until soft, about 8 minutes.",
    "Add the garlic, zucchini and Italian seasoning and cook 2 minutes.",
    "Add the tomatoes and broth and bring to a boil.",
    "Add the beans and macaroni and simmer until the pasta is tender, about 10 minutes.",
    "Season with salt. It tastes even better the next day.",
])


# ─── Plant-based ──────────────────────────────────────────────────────────────
# Vegan unless they use dairy or eggs, so plant-based eaters get a real choice every night.

recipe("tofu-scramble", "Tofu Scramble", "🌱", "Breakfast", 15, "Easy", 2, (570, 30, 46, 30), [
    (14, "oz", "Extra-firm tofu", "drained"),
    (1, "tbsp", "Olive oil", ""),
    (0.5, "", "Yellow onion", "diced"),
    (1, "", "Bell pepper", "diced"),
    (0.5, "tsp", "Ground turmeric", ""),
    (0.5, "tsp", "Garlic powder", ""),
    (2, "cup", "Spinach", ""),
    (1, "", "Avocado", "sliced"),
    (4, "slice", "Sandwich bread", "toasted"),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Pat the tofu dry with paper towels.",
    "Heat the oil in a nonstick pan over medium heat. Cook the onion and bell pepper until soft, about 5 minutes.",
    "Crumble the tofu into the pan with your hands in bite-size pieces.",
    "Add the turmeric, garlic powder and a big pinch of salt and pepper. Cook, stirring, until the tofu is hot and evenly yellow, about 5 minutes.",
    "Add the spinach and stir until wilted, about 1 minute.",
    "Serve with the toast and sliced avocado.",
])

recipe("black-bean-tacos", "Black Bean Tacos", "🌮", "Vegetarian", 20, "Easy", 4, (420, 15, 64, 12), [
    (1, "tbsp", "Vegetable oil", ""),
    (0.5, "", "Yellow onion", "diced"),
    (2, "clove", "Garlic", "minced"),
    (2, "tsp", "Chili powder", ""),
    (1, "tsp", "Ground cumin", ""),
    (2, "can", "Black beans", "15 oz each, drained and rinsed"),
    (0.5, "tsp", "Salt", ""),
    (8, "", "Corn tortillas", "6-inch"),
    (1, "", "Avocado", "sliced"),
    (1, "", "Lime", ""),
    (0.5, "cup", "Salsa", ""),
    (0.25, "bunch", "Fresh cilantro", "chopped"),
], [
    "Heat the oil in a pan over medium heat. Cook the onion until soft, about 5 minutes.",
    "Add the garlic, chili powder and cumin and cook 30 seconds.",
    "Add the beans, salt and 1/4 cup water. Simmer 5 minutes, mashing about half the beans with a fork.",
    "Warm the tortillas in a dry pan for about 30 seconds per side until soft and lightly charred.",
    "Squeeze the lime over the avocado slices.",
    "Fill the tortillas with the beans, avocado and salsa. Top with cilantro.",
])

recipe("teriyaki-tofu", "Teriyaki Tofu Bowls", "🍱", "Vegetarian", 35, "Easy", 4, (500, 17, 78, 13), [
    (14, "oz", "Extra-firm tofu", "cut into cubes"),
    (2, "tbsp", "Cornstarch", ""),
    (2, "tbsp", "Vegetable oil", ""),
    (1, "head", "Broccoli", "cut into small florets"),
    (2, "", "Carrots", "thinly sliced"),
    (0.25, "cup", "Soy sauce", ""),
    (3, "tbsp", "Brown sugar", ""),
    (2, "clove", "Garlic", "minced"),
    (1, "tbsp", "Ginger", "grated"),
    (2, "", "Green onions", "sliced"),
    (1.5, "cup", "White rice", "uncooked"),
], [
    "Cook the rice according to the package directions.",
    "Pat the tofu dry with paper towels and toss it with 1 tbsp cornstarch.",
    "Heat the oil in a large nonstick pan over medium-high heat. Cook the tofu, turning now and then, until golden and crisp, 8 to 10 minutes. Move it to a plate.",
    "Whisk the soy sauce, brown sugar, garlic, ginger, the remaining 1 tbsp cornstarch and 1/2 cup water in a small bowl.",
    "Add the broccoli, carrots and 2 tbsp water to the pan. Cover and cook 3 to 4 minutes until crisp-tender.",
    "Return the tofu, pour in the sauce and stir until thick and glossy, about 1 minute.",
    "Serve over rice and top with green onions.",
])

recipe("three-bean-chili", "Three-Bean Chili", "🫘", "Vegetarian", 40, "Easy", 4, (400, 18, 63, 9), [
    (2, "tbsp", "Olive oil", ""),
    (1, "", "Yellow onion", "diced"),
    (1, "", "Bell pepper", "diced"),
    (3, "clove", "Garlic", "minced"),
    (2, "tbsp", "Chili powder", ""),
    (1, "tsp", "Ground cumin", ""),
    (1, "can", "Crushed tomatoes", "28 oz"),
    (1, "can", "Kidney beans", "15 oz, drained and rinsed"),
    (1, "can", "Black beans", "15 oz, drained and rinsed"),
    (1, "can", "Pinto beans", "15 oz, drained and rinsed"),
    (1, "cup", "Vegetable broth", ""),
    (1, "tsp", "Salt", ""),
], [
    "Heat the oil in a large pot over medium heat. Cook the onion and bell pepper until soft, about 7 minutes.",
    "Add the garlic, chili powder and cumin and cook 1 minute.",
    "Add the crushed tomatoes, all the beans, the broth and the salt. Bring to a boil.",
    "Lower the heat and simmer, stirring now and then, until thick, about 25 minutes.",
    "Taste and add more salt or chili powder if you like. It tastes even better the next day.",
])

recipe("lentil-soup", "Lentil Soup", "🍲", "Vegetarian", 45, "Easy", 4, (310, 16, 44, 8), [
    (2, "tbsp", "Olive oil", ""),
    (1, "", "Yellow onion", "diced"),
    (2, "", "Carrots", "diced"),
    (2, "stalk", "Celery", "diced"),
    (3, "clove", "Garlic", "minced"),
    (1, "tsp", "Ground cumin", ""),
    (1, "cup", "Brown lentils", "rinsed"),
    (1, "can", "Diced tomatoes", "14.5 oz"),
    (4, "cup", "Vegetable broth", ""),
    (2, "cup", "Spinach", ""),
    (1, "", "Lemon", ""),
    (1, "tsp", "Salt", ""),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Heat the oil in a large pot over medium heat. Cook the onion, carrots and celery until soft, about 8 minutes.",
    "Add the garlic and cumin and cook 1 minute.",
    "Add the lentils, tomatoes, broth and salt. Bring to a boil.",
    "Lower the heat, cover and simmer until the lentils are tender, about 25 minutes.",
    "Stir in the spinach until wilted, then squeeze in the juice of the lemon. Season with pepper.",
])

recipe("peanut-noodles", "Peanut Noodles", "🥜", "Vegetarian", 20, "Easy", 4, (630, 22, 80, 25), [
    (12, "oz", "Spaghetti", ""),
    (0.5, "cup", "Peanut butter", "creamy"),
    (3, "tbsp", "Soy sauce", ""),
    (2, "tbsp", "Maple syrup", ""),
    (1, "tbsp", "Sesame oil", ""),
    (2, "clove", "Garlic", "grated"),
    (1, "", "Lime", ""),
    (1, "", "Cucumber", "cut into thin matchsticks"),
    (3, "", "Green onions", "sliced"),
    (0.25, "cup", "Chopped peanuts", ""),
], [
    "Cook the spaghetti according to the package directions. Save 1/2 cup of the pasta water, then drain and rinse the noodles under cold water.",
    "Whisk the peanut butter, soy sauce, maple syrup, sesame oil, garlic and the juice of the lime in a large bowl.",
    "Whisk in the hot pasta water a little at a time until the sauce is smooth and pourable.",
    "Add the noodles, cucumber and most of the green onions and toss to coat.",
    "Top with the peanuts and the remaining green onions. Serve warm or cold.",
])

recipe("aloo-gobi", "Aloo Gobi", "🥔", "Vegetarian", 40, "Easy", 4, (300, 7, 44, 11), [
    (3, "tbsp", "Vegetable oil", ""),
    (1, "", "Yellow onion", "diced"),
    (3, "clove", "Garlic", "minced"),
    (1, "tbsp", "Ginger", "grated"),
    (1, "tsp", "Ground cumin", ""),
    (1, "tsp", "Ground turmeric", ""),
    (1, "tsp", "Garam masala", ""),
    (2, "", "Russet potatoes", "cut into 1-inch cubes"),
    (1, "head", "Cauliflower", "cut into small florets"),
    (1, "", "Tomato", "chopped"),
    (1.5, "tsp", "Salt", ""),
    (0.25, "bunch", "Fresh cilantro", "chopped"),
], [
    "Heat the oil in a large pan over medium heat. Cook the onion until soft and golden, about 6 minutes.",
    "Add the garlic, ginger, cumin, turmeric and garam masala and cook 1 minute.",
    "Add the potatoes and cauliflower and stir until coated in the spices.",
    "Add the tomato, salt and 1/4 cup water. Cover and cook over medium-low heat, stirring now and then, until the vegetables are tender, 20 to 25 minutes.",
    "Uncover and cook a few minutes more so the vegetables dry out and brown a little.",
    "Top with cilantro and serve.",
])

recipe("coconut-chickpea-curry", "Coconut Chickpea Curry", "🥥", "Vegetarian", 30, "Easy", 4, (480, 14, 72, 14), [
    (1, "tbsp", "Vegetable oil", ""),
    (1, "", "Yellow onion", "diced"),
    (3, "clove", "Garlic", "minced"),
    (1, "tbsp", "Ginger", "grated"),
    (2, "tsp", "Garam masala", ""),
    (1, "tsp", "Ground turmeric", ""),
    (1, "can", "Diced tomatoes", "14.5 oz"),
    (2, "can", "Chickpeas", "15 oz each, drained"),
    (1, "can", "Light coconut milk", "13.5 oz"),
    (3, "cup", "Spinach", ""),
    (1, "tsp", "Salt", ""),
    (1, "cup", "White rice", "uncooked"),
], [
    "Cook the rice according to the package directions.",
    "Heat the oil in a large pan over medium heat. Cook the onion until soft, about 6 minutes.",
    "Add the garlic, ginger, garam masala and turmeric and cook 1 minute.",
    "Stir in the tomatoes, chickpeas, coconut milk and salt. Simmer until slightly thickened, about 15 minutes.",
    "Stir in the spinach until wilted, about 1 minute.",
    "Serve over rice.",
])

recipe("hummus-veggie-wraps", "Hummus Veggie Wraps", "🌯", "Vegetarian", 10, "Easy", 2, (450, 13, 54, 21), [
    (2, "", "Flour tortillas", "large, burrito size"),
    (0.5, "cup", "Hummus", ""),
    (1, "cup", "Spinach", ""),
    (0.5, "", "Cucumber", "thinly sliced"),
    (1, "", "Tomato", "sliced"),
    (0.5, "", "Bell pepper", "thinly sliced"),
    (0.25, "", "Red onion", "thinly sliced"),
    (0.5, "", "Avocado", "sliced"),
    (0.5, "", "Lemon", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Warm the tortillas in the microwave for 20 seconds so they fold without cracking.",
    "Spread 1/4 cup hummus down the middle of each tortilla.",
    "Layer on the spinach, cucumber, tomato, bell pepper, red onion and avocado.",
    "Squeeze the lemon over the vegetables and season with salt and pepper.",
    "Fold in the sides, roll up tightly and cut in half. Wrap in foil to pack for lunch.",
])

recipe("black-bean-burgers", "Black Bean Burgers", "🍔", "Vegetarian", 30, "Easy", 4, (500, 19, 82, 11), [
    (3, "tbsp", "Vegetable oil", ""),
    (0.5, "", "Yellow onion", "finely diced"),
    (2, "clove", "Garlic", "minced"),
    (2, "can", "Black beans", "15 oz each, drained, rinsed and patted dry"),
    (0.75, "cup", "Breadcrumbs", ""),
    (2, "tbsp", "All-purpose flour", ""),
    (1, "tsp", "Ground cumin", ""),
    (1, "tsp", "Chili powder", ""),
    (1, "tsp", "Salt", ""),
    (4, "", "Hamburger buns", ""),
    (0.5, "head", "Romaine lettuce", "leaves"),
    (1, "", "Tomato", "sliced"),
    (0.25, "cup", "Ketchup", "for serving"),
], [
    "Heat 1 tbsp oil in a large nonstick pan over medium heat. Cook the onion until soft, about 5 minutes. Add the garlic and cook 30 seconds.",
    "Mash the beans in a large bowl with a fork until mostly smooth, leaving a few whole beans for texture.",
    "Stir in the onion and garlic, breadcrumbs, flour, cumin, chili powder and salt until the mix holds together.",
    "Shape into 4 patties about 1/2 inch thick. Chill them 10 minutes if you have time so they hold together better.",
    "Heat the remaining 2 tbsp oil in the same pan over medium heat. Cook the patties until crisp and hot all the way through, 4 to 5 minutes per side, flipping gently.",
    "Toast the buns and build the burgers with lettuce, tomato and ketchup.",
])

recipe("pasta-arrabbiata", "Penne Arrabbiata", "🌶️", "Pasta", 25, "Easy", 4, (580, 18, 99, 12), [
    (1, "lb", "Penne", ""),
    (3, "tbsp", "Olive oil", ""),
    (4, "clove", "Garlic", "thinly sliced"),
    (1, "tsp", "Red pepper flakes", "use less for mild"),
    (1, "can", "Crushed tomatoes", "28 oz"),
    (1, "tsp", "Salt", ""),
    (0.5, "bunch", "Fresh basil", ""),
], [
    "Bring a large pot of salted water to a boil and cook the penne according to the package directions. Save 1/2 cup of the pasta water, then drain.",
    "Meanwhile, heat the oil in a large pan over medium heat. Cook the garlic and red pepper flakes until fragrant, about 1 minute. Don't let the garlic brown.",
    "Add the crushed tomatoes and salt and simmer until slightly thickened, about 15 minutes.",
    "Add the penne to the sauce with a splash of pasta water and toss to coat.",
    "Tear the basil over the top and serve.",
])

recipe("vegetable-lasagna", "Vegetable Lasagna", "🍝", "Pasta", 75, "Medium", 6, (530, 28, 45, 26), [
    (9, "", "Lasagna noodles", ""),
    (1, "tbsp", "Olive oil", ""),
    (2, "", "Zucchini", "diced"),
    (8, "oz", "Mushrooms", "sliced"),
    (3, "clove", "Garlic", "minced"),
    (5, "cup", "Spinach", ""),
    (1.75, "cup", "Ricotta", ""),
    (1, "tsp", "Italian seasoning", ""),
    (0.5, "cup", "Grated Parmesan", ""),
    (3, "cup", "Marinara sauce", ""),
    (2, "cup", "Shredded mozzarella", ""),
    (TO_TASTE, "", "Salt", "to taste"),
], [
    "Heat the oven to 375°F. Cook the noodles according to the package directions, drain and lay them flat so they don't stick.",
    "Heat the oil in a large pan over medium-high heat. Cook the zucchini and mushrooms with a pinch of salt until browned and their liquid cooks off, about 8 minutes. Add the garlic and spinach and stir until wilted.",
    "Stir the ricotta, Italian seasoning, half the Parmesan and a pinch of salt together in a bowl.",
    "Spread 1 cup marinara in a 9x13-inch baking dish. Layer 3 noodles, half the ricotta, half the vegetables, 1/2 cup marinara and 2/3 cup mozzarella.",
    "Repeat the layers, then top with the last 3 noodles, the remaining marinara, mozzarella and Parmesan.",
    "Cover with foil and bake 25 minutes. Uncover and bake 15 minutes more until bubbly and golden.",
    "Let it rest 10 minutes before cutting so the layers hold together.",
])

recipe("palak-paneer", "Palak Paneer", "🥬", "Vegetarian", 35, "Easy", 4, (520, 20, 50, 26), [
    (1, "cup", "White rice", "uncooked"),
    (20, "oz", "Frozen chopped spinach", "2 boxes, thawed"),
    (8, "oz", "Paneer", "cut into cubes"),
    (2, "tbsp", "Vegetable oil", ""),
    (1, "", "Yellow onion", "diced"),
    (3, "clove", "Garlic", "minced"),
    (1, "tbsp", "Ginger", "grated"),
    (1, "tsp", "Ground cumin", ""),
    (1, "tsp", "Garam masala", ""),
    (1, "", "Tomato", "chopped"),
    (1, "tsp", "Salt", ""),
    (0.25, "cup", "Heavy cream", ""),
], [
    "Cook the rice according to the package directions.",
    "Squeeze as much water as you can out of the thawed spinach.",
    "Heat 1 tbsp oil in a large pan over medium heat. Brown the paneer on a couple of sides, about 4 minutes, and move it to a plate.",
    "Add the remaining oil and the onion and cook until soft, about 6 minutes. Add the garlic, ginger, cumin and garam masala and cook 1 minute.",
    "Add the tomato, spinach, salt and 1/2 cup water and simmer 5 minutes.",
    "Blend with an immersion blender (or in a blender) until mostly smooth, then return to the pan.",
    "Stir in the cream and paneer and simmer 3 minutes. Serve over rice.",
])

recipe("spinach-mushroom-quesadillas", "Spinach & Mushroom Quesadillas", "🫓", "Vegetarian", 20, "Easy", 2, (620, 25, 57, 32), [
    (1, "tbsp", "Olive oil", ""),
    (8, "oz", "Mushrooms", "sliced"),
    (1, "clove", "Garlic", "minced"),
    (2, "cup", "Spinach", ""),
    (4, "", "Flour tortillas", "8-inch"),
    (1, "cup", "Shredded mozzarella", ""),
    (0.5, "cup", "Salsa", "for serving"),
    (0.25, "cup", "Sour cream", "for serving"),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Heat the oil in a large pan over medium-high heat. Cook the mushrooms with a pinch of salt until browned and their liquid cooks off, about 6 minutes.",
    "Add the garlic and spinach and stir until the spinach wilts, about 1 minute. Season with pepper, move to a plate and wipe out the pan.",
    "Sprinkle cheese over half of each tortilla, add the mushrooms and spinach, top with more cheese and fold closed.",
    "Cook the quesadillas over medium heat 2 to 3 minutes per side until golden and the cheese melts.",
    "Cut into wedges and serve with salsa and sour cream.",
])

recipe("eggplant-parmesan", "Eggplant Parmesan", "🍆", "Vegetarian", 65, "Medium", 4, (730, 30, 79, 32), [
    (2, "", "Eggplant", "medium, sliced into 1/2-inch rounds"),
    (4, "tbsp", "Olive oil", ""),
    (1, "tsp", "Salt", ""),
    (0.5, "cup", "Breadcrumbs", ""),
    (1, "tsp", "Italian seasoning", ""),
    (0.75, "cup", "Grated Parmesan", ""),
    (2, "cup", "Marinara sauce", ""),
    (1.5, "cup", "Shredded mozzarella", ""),
    (0.5, "bunch", "Fresh basil", ""),
    (8, "oz", "Spaghetti", "for serving"),
], [
    "Heat the oven to 425°F. Brush both sides of the eggplant slices with the oil and sprinkle with the salt.",
    "Roast on two baking sheets until tender and browned, about 20 minutes, flipping halfway. Lower the oven to 375°F.",
    "Mix the breadcrumbs, Italian seasoning and 1/4 cup of the Parmesan in a small bowl.",
    "Spread 1/2 cup marinara in a 9x13-inch baking dish. Layer half the eggplant, half the remaining marinara, half the mozzarella and half the remaining Parmesan. Repeat the layers.",
    "Sprinkle the breadcrumb mix over the top and bake until bubbly and golden, about 25 minutes.",
    "Meanwhile, cook the spaghetti according to the package directions.",
    "Let the eggplant rest 5 minutes, top with torn basil and serve with the spaghetti.",
])

recipe("mushroom-stroganoff", "Mushroom Stroganoff", "🍄", "Vegetarian", 30, "Easy", 4, (550, 17, 72, 22), [
    (12, "oz", "Egg noodles", ""),
    (2, "tbsp", "Butter", ""),
    (1, "tbsp", "Olive oil", ""),
    (16, "oz", "Mushrooms", "sliced"),
    (1, "", "Yellow onion", "diced"),
    (3, "clove", "Garlic", "minced"),
    (1, "tsp", "Dried thyme", ""),
    (1, "tbsp", "All-purpose flour", ""),
    (1.5, "cup", "Vegetable broth", ""),
    (1, "tbsp", "Soy sauce", ""),
    (0.75, "cup", "Sour cream", ""),
    (TO_TASTE, "", "Salt", "to taste"),
    (TO_TASTE, "", "Black pepper", "to taste"),
], [
    "Cook the egg noodles according to the package directions and drain.",
    "Melt the butter with the oil in a large pan over medium-high heat. Cook the mushrooms with a pinch of salt, stirring only now and then, until browned, about 8 minutes.",
    "Add the onion and cook until soft, about 4 minutes. Add the garlic and thyme and cook 30 seconds.",
    "Sprinkle in the flour and stir for 1 minute.",
    "Stir in the broth and soy sauce and simmer until slightly thickened, about 3 minutes.",
    "Take the pan off the heat and stir in the sour cream. Season with salt and pepper.",
    "Toss with the noodles and serve.",
])


# ─── Checks ───────────────────────────────────────────────────────────────────

def family(unit):
    if unit in ("cup", "tbsp", "tsp", "pinch"):
        return "volume"
    if unit in ("lb", "oz"):
        return "weight"
    return unit


def check():
    ids = set()
    for r in recipes:
        where = f'{r["id"]}:'
        assert r["id"] not in ids, f"{where} duplicate id"
        ids.add(r["id"])
        assert r["category"] in CATEGORIES, f"{where} unknown category {r['category']}"
        assert len(r["steps"]) <= 8, f"{where} {len(r['steps'])} steps (max 8)"
        to_buy = [i for i in r["ingredients"] if not i["isStaple"]]
        assert len(to_buy) <= 10, f"{where} {len(to_buy)} ingredients to buy (max 10)"
        for i in r["ingredients"]:
            assert i["aisle"] in AISLES, f'{where} "{i["name"]}" is not in CATALOG'
            assert i["unit"] in UNITS, f'{where} unknown unit "{i["unit"]}"'
            assert i["amount"] is not None or i["note"], f'{where} "{i["name"]}" needs an amount or a note'
            package_unit = PACKAGE_OF[i["name"]][4]
            assert i["amount"] is None or family(i["unit"]) == family(package_unit), \
                f'{where} "{i["name"]}" is in {i["unit"] or "a count"} but sold in {package_unit or "a count"}'
    for category in CATEGORIES:
        assert any(r["category"] == category for r in recipes), f"no recipes in {category}"


check()
OUT.write_text(json.dumps(recipes, ensure_ascii=False, indent=1) + "\n")
catalog = [
    {"name": name, "aisle": aisle, "isStaple": aisle == "Pantry Staples", "perishable": perishable,
     "soldBy": sold_by, "package": package, "size": size, "unit": unit, "price": price}
    for aisle, items in CATALOG.items()
    for (name, sold_by, package, size, unit, price, perishable) in items
]
CATALOG_OUT.write_text(json.dumps(catalog, ensure_ascii=False, indent=1) + "\n")
print(f"Wrote {len(recipes)} recipes to {OUT.relative_to(Path.cwd()) if OUT.is_relative_to(Path.cwd()) else OUT}")
for category in CATEGORIES:
    print(f"  {category}: {sum(r['category'] == category for r in recipes)}")
