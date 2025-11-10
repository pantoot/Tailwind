#!/usr/bin/env python3
"""
Tailwind App Icon Generator
Creates all required iOS app icon sizes from a base design
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_app_icon(size):
    """Create the Tailwind app icon with phoenix design"""
    import math

    # Create image with gradient background (desert sunset)
    img = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(img)

    # Desert sunset gradient (vibrant orange to deep red)
    for y in range(size):
        ratio = y / size
        r = int(255 - (ratio * 70))    # 255 -> 185
        g = int(140 - (ratio * 100))   # 140 -> 40
        b = int(30 + (ratio * 20))     # 30 -> 50
        color = (r, g, b)
        draw.rectangle([(0, y), (size, y+1)], fill=color)

    center_x = size // 2
    s = size / 100.0

    # Create a recognizable phoenix bird silhouette
    # Similar to City of Phoenix logo - bird with spread wings from front view

    # Phoenix head at top
    head_y = int(s * 20)
    head_radius = int(s * 10)

    # Head circle
    draw.ellipse(
        [(center_x - head_radius, head_y - head_radius),
         (center_x + head_radius, head_y + head_radius)],
        fill='white'
    )

    # Pointed beak extending upward (like Pivot Cycles style)
    beak_points = [
        (center_x - int(s * 3), head_y - head_radius),
        (center_x, head_y - head_radius - int(s * 8)),
        (center_x + int(s * 3), head_y - head_radius)
    ]
    draw.polygon(beak_points, fill='white')

    # Eye crest/plume (small triangular points)
    left_crest = [
        (center_x - head_radius, head_y - int(s * 4)),
        (center_x - head_radius - int(s * 5), head_y - int(s * 8)),
        (center_x - head_radius, head_y - int(s * 6))
    ]
    right_crest = [
        (center_x + head_radius, head_y - int(s * 4)),
        (center_x + head_radius + int(s * 5), head_y - int(s * 8)),
        (center_x + head_radius, head_y - int(s * 6))
    ]
    draw.polygon(left_crest, fill='white')
    draw.polygon(right_crest, fill='white')

    # Neck/body - wider at bottom
    neck_start_y = head_y + head_radius
    body_end_y = int(s * 60)
    neck_width = int(s * 6)
    body_width = int(s * 12)

    body_points = [
        (center_x - neck_width, neck_start_y),
        (center_x - body_width, body_end_y),
        (center_x + body_width, body_end_y),
        (center_x + neck_width, neck_start_y)
    ]
    draw.polygon(body_points, fill='white')

    # Spread wings - large and dramatic (front view, both wings visible)
    wing_attach_y = int(s * 35)  # Where wings connect to body

    # Left wing - curved upward and outward
    left_wing = [
        # Connection to body
        (center_x - body_width, wing_attach_y),
        # Outer wing tip (high and wide)
        (int(s * 8), int(s * 25)),
        # Wing leading edge
        (int(s * 15), int(s * 30)),
        # Inner wing
        (center_x - body_width, int(s * 45))
    ]
    draw.polygon(left_wing, fill='white')

    # Right wing - mirror
    right_wing = [
        (center_x + body_width, wing_attach_y),
        (int(s * 92), int(s * 25)),
        (int(s * 85), int(s * 30)),
        (center_x + body_width, int(s * 45))
    ]
    draw.polygon(right_wing, fill='white')

    # Wing feather details (notches for definition)
    # Left wing feathers
    for i in range(3):
        feather_x = int(s * (10 + i * 8))
        feather_y = int(s * (26 + i * 4))
        feather = [
            (feather_x, feather_y),
            (feather_x - int(s * 5), feather_y + int(s * 8)),
            (feather_x + int(s * 2), feather_y + int(s * 6))
        ]
        draw.polygon(feather, fill='white')

    # Right wing feathers
    for i in range(3):
        feather_x = int(s * (90 - i * 8))
        feather_y = int(s * (26 + i * 4))
        feather = [
            (feather_x, feather_y),
            (feather_x + int(s * 5), feather_y + int(s * 8)),
            (feather_x - int(s * 2), feather_y + int(s * 6))
        ]
        draw.polygon(feather, fill='white')

    # Tail feathers - dramatic spread at bottom
    tail_start_y = body_end_y

    # Center tail feather (longest)
    center_tail = [
        (center_x - int(s * 4), tail_start_y),
        (center_x, int(s * 85)),
        (center_x + int(s * 4), tail_start_y)
    ]
    draw.polygon(center_tail, fill='white')

    # Left tail feathers
    left_tail_1 = [
        (center_x - int(s * 8), tail_start_y),
        (center_x - int(s * 18), int(s * 80)),
        (center_x - int(s * 4), tail_start_y + int(s * 5))
    ]
    draw.polygon(left_tail_1, fill='white')

    left_tail_2 = [
        (center_x - int(s * 12), tail_start_y),
        (center_x - int(s * 28), int(s * 75)),
        (center_x - int(s * 8), tail_start_y + int(s * 5))
    ]
    draw.polygon(left_tail_2, fill='white')

    # Right tail feathers
    right_tail_1 = [
        (center_x + int(s * 8), tail_start_y),
        (center_x + int(s * 18), int(s * 80)),
        (center_x + int(s * 4), tail_start_y + int(s * 5))
    ]
    draw.polygon(right_tail_1, fill='white')

    right_tail_2 = [
        (center_x + int(s * 12), tail_start_y),
        (center_x + int(s * 28), int(s * 75)),
        (center_x + int(s * 8), tail_start_y + int(s * 5))
    ]
    draw.polygon(right_tail_2, fill='white')

    return img

def generate_all_icons():
    """Generate all required iOS app icon sizes"""

    # iOS app icon sizes (in pixels)
    sizes = {
        # iPhone
        'iphone_2x': 120,
        'iphone_3x': 180,

        # iPad
        'ipad_1x': 76,
        'ipad_2x': 152,
        'ipad_pro': 167,  # 83.5x83.5@2x for iPad Pro

        # App Store
        'app_store': 1024,

        # Settings
        'settings_1x': 29,
        'settings_2x': 58,
        'settings_3x': 87,

        # Spotlight
        'spotlight_1x': 40,
        'spotlight_2x': 80,
        'spotlight_3x': 120,

        # Notification
        'notification_1x': 20,
        'notification_2x': 40,
        'notification_3x': 60,
    }

    output_dir = 'AppIcon.appiconset'
    os.makedirs(output_dir, exist_ok=True)

    print("🎨 Generating Tailwind App Icons...")

    for name, size in sizes.items():
        icon = create_app_icon(size)
        filename = f'{output_dir}/icon_{name}.png'
        icon.save(filename, 'PNG')
        print(f"✅ Created {name}: {size}x{size}px")

    # Create Contents.json for Xcode
    contents_json = {
        "images": [
            {"size": "20x20", "idiom": "iphone", "filename": "icon_notification_2x.png", "scale": "2x"},
            {"size": "20x20", "idiom": "iphone", "filename": "icon_notification_3x.png", "scale": "3x"},
            {"size": "20x20", "idiom": "ipad", "filename": "icon_notification_1x.png", "scale": "1x"},
            {"size": "20x20", "idiom": "ipad", "filename": "icon_notification_2x.png", "scale": "2x"},
            {"size": "29x29", "idiom": "iphone", "filename": "icon_settings_2x.png", "scale": "2x"},
            {"size": "29x29", "idiom": "iphone", "filename": "icon_settings_3x.png", "scale": "3x"},
            {"size": "29x29", "idiom": "ipad", "filename": "icon_settings_1x.png", "scale": "1x"},
            {"size": "29x29", "idiom": "ipad", "filename": "icon_settings_2x.png", "scale": "2x"},
            {"size": "40x40", "idiom": "iphone", "filename": "icon_spotlight_2x.png", "scale": "2x"},
            {"size": "40x40", "idiom": "iphone", "filename": "icon_spotlight_3x.png", "scale": "3x"},
            {"size": "40x40", "idiom": "ipad", "filename": "icon_spotlight_1x.png", "scale": "1x"},
            {"size": "40x40", "idiom": "ipad", "filename": "icon_spotlight_2x.png", "scale": "2x"},
            {"size": "60x60", "idiom": "iphone", "filename": "icon_iphone_2x.png", "scale": "2x"},
            {"size": "60x60", "idiom": "iphone", "filename": "icon_iphone_3x.png", "scale": "3x"},
            {"size": "76x76", "idiom": "ipad", "filename": "icon_ipad_1x.png", "scale": "1x"},
            {"size": "76x76", "idiom": "ipad", "filename": "icon_ipad_2x.png", "scale": "2x"},
            {"size": "83.5x83.5", "idiom": "ipad", "filename": "icon_ipad_pro.png", "scale": "2x"},
            {"size": "1024x1024", "idiom": "ios-marketing", "filename": "icon_app_store.png", "scale": "1x"}
        ],
        "info": {"version": 1, "author": "xcode"}
    }

    import json
    with open(f'{output_dir}/Contents.json', 'w') as f:
        json.dump(contents_json, f, indent=2)

    print(f"\n✨ All icons generated in '{output_dir}/'")
    print(f"📁 Copy this folder to: DesertMetrics/Assets.xcassets/")
    print(f"🎯 Replace the existing AppIcon.appiconset folder")

if __name__ == '__main__':
    try:
        generate_all_icons()
        print("\n🎉 App icon generation complete!")
    except ImportError:
        print("❌ Error: Pillow library not found")
        print("📦 Install with: pip3 install Pillow")
    except Exception as e:
        print(f"❌ Error: {e}")
