import os
from PIL import Image, ImageDraw, ImageFilter

RES_DIR = r"D:\Magister\Semester 1\Pembelajaran Mesin\ml-inventaris\android\inventaris_ml\android\app\src\main\res"

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

ADAPTIVE_FOREGROUND_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}

def create_base_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    margin = size * 0.08
    corner_radius = size * 0.22
    rect = [margin, margin, size - margin, size - margin]

    # Gradient background (Emerald #059669 to Teal #14b8a6)
    grad_img = Image.new("RGBA", (size, size))
    for y in range(size):
        for x in range(size):
            t = (x + (size - y)) / (2 * size)
            t = max(0.0, min(1.0, t))
            r = int(5 + t * (20 - 5))
            g = int(150 + t * (184 - 150))
            b = int(105 + t * (166 - 105))
            grad_img.putpixel((x, y), (r, g, b, 255))

    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(rect, radius=int(corner_radius), fill=255)

    base_card = Image.composite(grad_img, Image.new("RGBA", (size, size), (0, 0, 0, 0)), mask)

    # Soft drop shadow
    shadow_mask = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_mask)
    shadow_rect = [margin, margin + size * 0.03, size - margin, size - margin + size * 0.03]
    s_draw.rounded_rectangle(shadow_rect, radius=int(corner_radius), fill=(0, 0, 0, 85))
    shadow_blurred = shadow_mask.filter(ImageFilter.GaussianBlur(radius=size * 0.04))

    # White icon in center
    icon_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    i_draw = ImageDraw.Draw(icon_layer)

    cx = size / 2
    cy = size / 2
    arm_length = size * 0.44
    arm_thickness = size * 0.11
    half_t = arm_thickness / 2
    half_l = arm_length / 2
    r_arm = half_t

    i_draw.rounded_rectangle(
        [cx - half_t, cy - half_l, cx + half_t, cy + half_l],
        radius=int(r_arm),
        fill=(255, 255, 255, 255)
    )

    i_draw.rounded_rectangle(
        [cx - half_l, cy - half_t, cx + half_l, cy + half_t],
        radius=int(r_arm),
        fill=(255, 255, 255, 255)
    )

    inner_dot_r = size * 0.032
    i_draw.ellipse(
        [cx - inner_dot_r, cy - inner_dot_r, cx + inner_dot_r, cy + inner_dot_r],
        fill=(16, 185, 129, 255)
    )

    final_img = Image.alpha_composite(shadow_blurred, base_card)
    final_img = Image.alpha_composite(final_img, icon_layer)
    return final_img

def create_adaptive_foreground(size=1024):
    # In adaptive icon (108dp canvas), icon fits safe zone (inner 66%)
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    i_draw = ImageDraw.Draw(img)

    cx = size / 2
    cy = size / 2
    arm_length = size * 0.42
    arm_thickness = size * 0.105
    half_t = arm_thickness / 2
    half_l = arm_length / 2
    r_arm = half_t

    i_draw.rounded_rectangle(
        [cx - half_t, cy - half_l, cx + half_t, cy + half_l],
        radius=int(r_arm),
        fill=(255, 255, 255, 255)
    )

    i_draw.rounded_rectangle(
        [cx - half_l, cy - half_t, cx + half_l, cy + half_t],
        radius=int(r_arm),
        fill=(255, 255, 255, 255)
    )

    inner_dot_r = size * 0.032
    i_draw.ellipse(
        [cx - inner_dot_r, cy - inner_dot_r, cx + inner_dot_r, cy + inner_dot_r],
        fill=(16, 185, 129, 255)
    )
    return img

def main():
    base_1024 = create_base_icon(1024)
    fore_1024 = create_adaptive_foreground(1024)

    # 1. Save standard ic_launcher.png
    for folder, dim in SIZES.items():
        out_dir = os.path.join(RES_DIR, folder)
        os.makedirs(out_dir, exist_ok=True)
        scaled = base_1024.resize((dim, dim), Image.Resampling.LANCZOS)
        out_path = os.path.join(out_dir, "ic_launcher.png")
        scaled.save(out_path, "PNG")
        print(f"Saved: {out_path} ({dim}x{dim})")

    # 2. Save adaptive foreground ic_launcher_foreground.png
    for folder, dim in ADAPTIVE_FOREGROUND_SIZES.items():
        out_dir = os.path.join(RES_DIR, folder)
        os.makedirs(out_dir, exist_ok=True)
        scaled = fore_1024.resize((dim, dim), Image.Resampling.LANCZOS)
        out_path = os.path.join(out_dir, "ic_launcher_foreground.png")
        scaled.save(out_path, "PNG")
        print(f"Saved: {out_path} ({dim}x{dim})")

    # 3. Create anydpi-v26/ic_launcher.xml
    anydpi_dir = os.path.join(RES_DIR, "mipmap-anydpi-v26")
    os.makedirs(anydpi_dir, exist_ok=True)
    xml_content = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
"""
    with open(os.path.join(anydpi_dir, "ic_launcher.xml"), "w", encoding="utf-8") as f:
        f.write(xml_content)
    print("Saved: anydpi-v26/ic_launcher.xml")

    # 4. Create colors.xml with background color if not present
    values_dir = os.path.join(RES_DIR, "values")
    os.makedirs(values_dir, exist_ok=True)
    colors_xml_path = os.path.join(values_dir, "colors.xml")
    colors_content = """<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">#059669</color>
</resources>
"""
    with open(colors_xml_path, "w", encoding="utf-8") as f:
        f.write(colors_content)
    print("Saved: values/colors.xml")

if __name__ == "__main__":
    main()
