import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(AquariumApp());
}

class AquariumApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: AquariumScreen(),
    );
  }
}

class AquariumScreen extends StatefulWidget {
  @override
  _AquariumScreenState createState() => _AquariumScreenState();
}

class _AquariumScreenState extends State<AquariumScreen>
    with SingleTickerProviderStateMixin {
  List<Fish> fishList = [];
  late AnimationController _controller;
  double swimmingSpeed = 1.0;
  Color fishColor = Colors.blue;
  final int maxFishCount = 10;
  late Database database;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _controller.addListener(() {
      setState(() {
        for (var fish in fishList) {
          fish.updatePosition();
        }
      });
    });

    _controller.repeat();
    _initializeDatabase().then((_) =>
        _loadPreferences()); // Load preferences after initializing the database
  }

  // In your database initialization method
  Future<void> _initializeDatabase() async {
    database = await openDatabase(
      join(await getDatabasesPath(), 'aquarium.db'),
      onCreate: (db, version) {
        return db
            .execute(
          'CREATE TABLE preferences(id INTEGER PRIMARY KEY, fishCount INTEGER, swimmingSpeed REAL, color INTEGER)',
        )
            .then((_) {
          return db.execute(
              'CREATE TABLE fish(id INTEGER PRIMARY KEY, color INTEGER, left REAL, top REAL)');
        });
      },
      version: 1,
    );
  }

  // Inside _savePreferences
  Future<void> _savePreferences() async {
    await database.delete('preferences');
    await database.insert('preferences', {
      'fishCount': fishList.length,
      'swimmingSpeed': swimmingSpeed,
      'color': fishColor.value,
    });

    await database.delete('fish'); // Clear existing fish records
    for (var fish in fishList) {
      await database.insert('fish', fish.toMap());
    }
  }

  Future<void> _loadPreferences() async {
    // Load general preferences (swimming speed, color, etc.)
    final List<Map<String, dynamic>> maps = await database.query('preferences');
    if (maps.isNotEmpty) {
      setState(() {
        swimmingSpeed = maps[0]['swimmingSpeed']?.toDouble() ?? 1.0;
        fishColor = Color(maps[0]['color'] ??
            Colors.blue.value); // Default to blue if color not found
      });
    }

    // Load fish data (positions and colors)
    final List<Map<String, dynamic>> fishMaps = await database.query('fish');
    if (fishMaps.isNotEmpty) {
      setState(() {
        fishList = fishMaps
            .map((map) => Fish.fromMap(map))
            .toList(); // Load each fish from its map
      });
    }
  }

  void _addFish() {
    if (fishList.length < maxFishCount) {
      setState(() {
        fishList.add(Fish(color: fishColor));
      });
    }
  }

  void _removeFish() {
    if (fishList.isNotEmpty) {
      setState(() {
        fishList.removeLast();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _savePreferences(); // Save preferences when disposing
    database.close(); // Close the database
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Aquarium App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue, width: 2),
                color: Colors.lightBlue[50],
              ),
              child: Stack(
                children: fishList.map((fish) => fish.build(context)).toList(),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addFish,
              child: Text('Add Fish'),
            ),
            ElevatedButton(
              onPressed: _removeFish,
              child: Text('Remove Fish'),
            ),
            // Save Settings Button
            ElevatedButton(
              onPressed: () {
                _savePreferences();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Preferences saved!')),
                );
              },
              child: Text('Save Settings'),
            ),
            SizedBox(height: 20),
            Text('Swimming Speed: ${swimmingSpeed.toStringAsFixed(1)}'),
            Slider(
              value: swimmingSpeed,
              min: 0.1,
              max: 5.0,
              onChanged: (value) {
                setState(() {
                  swimmingSpeed = value;
                });
              },
            ),
            SizedBox(height: 20),
            DropdownButton<Color>(
              value: fishColor,
              items: [
                DropdownMenuItem(
                  child: Text('Blue', style: TextStyle(color: Colors.blue)),
                  value: Colors.blue,
                ),
                DropdownMenuItem(
                  child: Text('Red', style: TextStyle(color: Colors.red)),
                  value: Colors.red,
                ),
                DropdownMenuItem(
                  child: Text('Green', style: TextStyle(color: Colors.green)),
                  value: Colors.green,
                ),
              ],
              onChanged: (color) {
                setState(() {
                  fishColor = color!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

class Fish {
  double left;
  double top;
  final Color color;
  double dx; // Change in x
  double dy; // Change in y

  Fish({required this.color})
      : left = Random().nextDouble() * 280, // Random initial position
        top = Random().nextDouble() * 280,
        dx = (Random().nextDouble() * 2 - 1), // Random horizontal direction
        dy = (Random().nextDouble() * 2 - 1); // Random vertical direction

  // Convert Fish to a map for saving to the database
  Map<String, dynamic> toMap() {
    return {
      'color': color.value,
      'left': left,
      'top': top,
    };
  }

  // Create Fish from a map loaded from the database
  factory Fish.fromMap(Map<String, dynamic> map) {
    return Fish(
      color: Color(map['color']),
    )
      ..left = map['left']?.toDouble() ?? 0.0 // Set position from map
      ..top = map['top']?.toDouble() ?? 0.0;
  }

  void updatePosition() {
    left += dx; // Update the left position
    top += dy; // Update the top position

    // Check for boundary collisions
    if (left < 0 || left > 280) {
      dx = -dx; // Change direction on x-axis
    }
    if (top < 0 || top > 280) {
      dy = -dy; // Change direction on y-axis
    }
  }

  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
