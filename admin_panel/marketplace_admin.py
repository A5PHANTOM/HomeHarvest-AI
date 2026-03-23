import streamlit as st
import requests
from datetime import datetime

# Configuration
BACKEND_URL = "http://127.0.0.1:8000"
ADMIN_PASSWORD = "admin123"

st.set_page_config(page_title="Marketplace Admin Panel", layout="wide")

# Initialize session state
if "authenticated" not in st.session_state:
    st.session_state["authenticated"] = False
if "items" not in st.session_state:
    st.session_state["items"] = []

# --- Authentication ---
def check_authentication():
    """Check if user is authenticated"""
    return st.session_state["authenticated"]

def authenticate(password):
    """Verify admin password"""
    if password == ADMIN_PASSWORD:
        st.session_state["authenticated"] = True
        return True
    return False

# --- API Calls ---
def get_marketplace_items():
    """Fetch all marketplace items"""
    try:
        response = requests.get(f"{BACKEND_URL}/api/marketplace/items")
        if response.status_code == 200:
            return response.json()
    except Exception as e:
        st.error(f"Error fetching items: {e}")
    return []

def create_marketplace_item(title, price, distance, seller, time_posted, image_url, description, is_out_of_stock):
    """Create a new marketplace item"""
    try:
        payload = {
            "title": title,
            "price": price,
            "distance": distance,
            "seller": seller,
            "time_posted": time_posted,
            "image_url": image_url,
            "description": description,
            "is_out_of_stock": is_out_of_stock,
        }
        auth = {"password": ADMIN_PASSWORD}
        response = requests.post(
            f"{BACKEND_URL}/api/marketplace/admin/items",
            json={"item": payload, "auth": auth}
        )
        if response.status_code == 200:
            return response.json()
        else:
            return {"error": response.json().get("detail", "Failed to create item")}
    except Exception as e:
        return {"error": str(e)}

def toggle_stock_status(item_id):
    """Toggle out-of-stock status"""
    try:
        auth = {"password": ADMIN_PASSWORD}
        response = requests.patch(
            f"{BACKEND_URL}/api/marketplace/items/{item_id}/stock",
            json=auth
        )
        if response.status_code == 200:
            return response.json()
        else:
            return {"error": response.json().get("detail", "Failed to update stock")}
    except Exception as e:
        return {"error": str(e)}

def delete_marketplace_item(item_id):
    """Delete a marketplace item"""
    try:
        auth = {"password": ADMIN_PASSWORD}
        response = requests.delete(
            f"{BACKEND_URL}/api/marketplace/items/{item_id}",
            json=auth
        )
        if response.status_code == 200:
            return response.json()
        else:
            return {"error": response.json().get("detail", "Failed to delete item")}
    except Exception as e:
        return {"error": str(e)}


def get_buy_now_messages():
    """Fetch buy-now inquiries from users"""
    try:
        auth = {"password": ADMIN_PASSWORD}
        response = requests.post(
            f"{BACKEND_URL}/api/marketplace/admin/messages",
            json=auth,
        )
        if response.status_code == 200:
            return response.json()
        return []
    except Exception as e:
        st.error(f"Error fetching messages: {e}")
        return []


def upload_item_image(uploaded_file):
    """Upload image file and return hosted image URL"""
    try:
        files = {
            "image": (
                uploaded_file.name,
                uploaded_file.getvalue(),
                uploaded_file.type or "application/octet-stream",
            )
        }
        data = {"password": ADMIN_PASSWORD}
        response = requests.post(
            f"{BACKEND_URL}/api/marketplace/admin/upload-image",
            data=data,
            files=files,
        )
        payload = response.json() if response.content else {}
        if response.status_code == 200:
            return payload.get("image_url", "")
        return {"error": payload.get("detail", "Image upload failed")}
    except Exception as e:
        return {"error": str(e)}

# --- UI ---
st.title("🌱 Marketplace Admin Panel")

if not check_authentication():
    st.info("Please authenticate to access the admin panel.")
    with st.form("auth_form"):
        password = st.text_input("Admin Password", type="password")
        submitted = st.form_submit_button("Authenticate")
        if submitted:
            if authenticate(password):
                st.success("✅ Authenticated!")
                st.rerun()
            else:
                st.error("❌ Invalid password")
else:
    # Sidebar logout
    with st.sidebar:
        if st.button("🚪 Logout"):
            st.session_state["authenticated"] = False
            st.rerun()
        st.markdown("---")
        st.markdown("**Authenticated Admin**")

    # Tabs
    tab1, tab2, tab3 = st.tabs(["📋 View Items", "➕ Add New Item", "📩 Buyer Messages"])

    with tab1:
        st.subheader("Marketplace Listings")
        
        # Refresh button
        if st.button("🔄 Refresh Items"):
            st.session_state["items"] = get_marketplace_items()
        
        # Load items if empty
        if not st.session_state["items"]:
            st.session_state["items"] = get_marketplace_items()
        
        if st.session_state["items"]:
            # Display items in a table-like format
            for item in st.session_state["items"]:
                with st.container(border=True):
                    col1, col2, col3 = st.columns([2, 1, 1])
                    
                    with col1:
                        st.markdown(f"**{item['title']}**")
                        if item.get("description"):
                            st.caption(item["description"])
                        st.markdown(f"💰 {item['price']} | 📍 {item['distance']} | 👤 {item['seller']}")
                        if item.get("image_url"):
                            st.caption(f"🖼️ Image: {item['image_url'][:50]}...")
                    
                    with col2:
                        stock_status = "🔴 Out of Stock" if item.get("is_out_of_stock") else "🟢 In Stock"
                        st.markdown(stock_status)
                    
                    with col3:
                        col3a, col3b = st.columns(2)
                        with col3a:
                            if st.button("📦 Toggle Stock", key=f"stock_{item['id']}"):
                                result = toggle_stock_status(item["id"])
                                if "error" not in result:
                                    st.success("Stock updated!")
                                    st.session_state["items"] = get_marketplace_items()
                                    st.rerun()
                                else:
                                    st.error(result["error"])
                        
                        with col3b:
                            if st.button("🗑️ Delete", key=f"delete_{item['id']}"):
                                result = delete_marketplace_item(item["id"])
                                if "error" not in result:
                                    st.success("Item deleted!")
                                    st.session_state["items"] = get_marketplace_items()
                                    st.rerun()
                                else:
                                    st.error(result["error"])
        else:
            st.info("No items in marketplace yet.")

    with tab2:
        st.subheader("Add New Marketplace Listing")
        
        with st.form("add_item_form"):
            col1, col2 = st.columns(2)
            
            with col1:
                title = st.text_input("Product Title *", placeholder="e.g., Fresh Tomatoes")
                price = st.text_input("Price *", placeholder="e.g., ₹200/kg")
                distance = st.text_input("Distance", value="Local", placeholder="e.g., 5 km")
                seller = st.text_input("Seller Name", value="Admin", placeholder="Your name")
            
            with col2:
                image_url = st.text_input("Image URL (optional)", placeholder="https://example.com/image.jpg")
                uploaded_image = st.file_uploader(
                    "Or upload image",
                    type=["jpg", "jpeg", "png", "webp"],
                    accept_multiple_files=False,
                )
                description = st.text_area("Description (optional)", placeholder="Product details...", height=80)
                is_out_of_stock = st.checkbox("Mark as Out of Stock")
            
            time_posted = datetime.now().strftime("%Y-%m-%d %H:%M")
            st.caption(f"Posted at: {time_posted}")
            
            submitted = st.form_submit_button("✅ Add Listing")
            
            if submitted:
                if not title or not price:
                    st.error("Title and Price are required!")
                else:
                    with st.spinner("Adding item..."):
                        final_image_url = image_url.strip()
                        if uploaded_image is not None:
                            upload_result = upload_item_image(uploaded_image)
                            if isinstance(upload_result, dict) and "error" in upload_result:
                                st.error(f"❌ {upload_result['error']}")
                                st.stop()
                            final_image_url = upload_result

                        result = create_marketplace_item(
                            title=title,
                            price=price,
                            distance=distance,
                            seller=seller,
                            time_posted=time_posted,
                            image_url=final_image_url,
                            description=description,
                            is_out_of_stock=1 if is_out_of_stock else 0,
                        )
                        
                        if "error" in result:
                            st.error(f"❌ {result['error']}")
                        else:
                            st.success(f"✅ Item added! (ID: {result.get('id')})")
                            st.session_state["items"] = get_marketplace_items()
                            st.rerun()

    with tab3:
        st.subheader("Buy Now Requests")
        st.caption("Messages submitted from app users with their Gmail ID")

        if st.button("🔄 Refresh Messages"):
            st.session_state["buy_messages"] = get_buy_now_messages()

        if "buy_messages" not in st.session_state:
            st.session_state["buy_messages"] = get_buy_now_messages()

        messages = st.session_state.get("buy_messages", [])
        if not messages:
            st.info("No buy requests yet.")
        else:
            for msg in messages:
                with st.container(border=True):
                    st.markdown(f"**Item:** {msg.get('item_title', 'Unknown')} (ID: {msg.get('item_id')})")
                    st.markdown(f"**Buyer Gmail:** {msg.get('buyer_email', '')}")
                    buyer_msg = msg.get("buyer_message", "")
                    st.markdown(f"**Message:** {buyer_msg if buyer_msg else '(No message)'}")
                    st.caption(f"Received: {msg.get('created_at', '')}")

    st.markdown("---")
    st.caption("🔐 Marketplace Admin Panel v1.0 | Password-protected")
