import math
import heapq
import urllib.request
import json
from typing import List, Tuple, Dict, Optional
from geopy.distance import geodesic
import logging
from app.services.safety_score_calculator import SafetyScoreCalculator

logger = logging.getLogger(__name__)

class RouteService:
    """Route service with OSRM real-road queries and A* dynamic grid fallback"""
    
    def __init__(self):
        self.grid_size = 100
        self.resolution = 0.001  # degrees per grid cell
        self.base_lat = 19.0
        self.base_lng = 72.8
        self.calculator = SafetyScoreCalculator()

    def _fetch_osrm_route(self, start: Tuple[float, float], end: Tuple[float, float]) -> List[Tuple[float, float]]:
        """Fetch actual road geometry using free OpenStreetMap OSRM routing engine (walking profile)"""
        try:
            # OSRM expects coordinates in (lng, lat) format
            url = f"http://router.project-osrm.org/route/v1/foot/{start[1]},{start[0]};{end[1]},{end[0]}?overview=full&geometries=geojson"
            req = urllib.request.Request(
                url, 
                headers={'User-Agent': 'SafeSphere-Safety-Heatmap-App/2.0'}
            )
            with urllib.request.urlopen(req, timeout=4) as response:
                data = json.loads(response.read().decode())
                if data.get("code") == "Ok" and data.get("routes"):
                    coords = data["routes"][0]["geometry"]["coordinates"]
                    # Convert back to (lat, lng) format
                    return [(float(lat), float(lng)) for lng, lat in coords]
        except Exception as e:
            logger.warning(f"OSRM real-road routing failed: {e}. Falling back to custom safety grid pathfinder.")
        return []

    def _calculate_distance(self, lat1: float, lng1: float, lat2: float, lng2: float) -> float:
        """Calculate distance in km using Haversine formula"""
        R = 6371.0
        lat1, lng1, lat2, lng2 = map(math.radians, [lat1, lng1, lat2, lng2])
        dlat = lat2 - lat1
        dlng = lng2 - lng1
        a = math.sin(dlat / 2)**2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2)**2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c

    def find_safe_route(self, start: Tuple[float, float], end: Tuple[float, float], 
                       unsafe_areas: List[Dict] = None, police_stations: List[Dict] = None,
                       hospitals: List[Dict] = None) -> Dict:
        """
        Find the safest route using OSRM queries or fallback A* grid mesh with safety scoring
        """
        try:
            # Update safety score calculator with nearby infrastructure
            self.calculator = SafetyScoreCalculator(
                police_stations=police_stations,
                hospitals=hospitals
            )
            
            # Recalculate base_lat, base_lng and resolution to wrap coordinates dynamically
            self.base_lat = min(start[0], end[0]) - 0.02
            self.base_lng = min(start[1], end[1]) - 0.02
            max_delta = max(abs(start[0] - end[0]), abs(start[1] - end[1]))
            self.resolution = max(0.0001, max_delta / (self.grid_size - 10))

            # 1. First run safety A* pathfinder to bypass unsafe coordinates and secure a green route
            # Convert to grid coordinates
            start_grid = self._lat_lng_to_grid(start)
            end_grid = self._lat_lng_to_grid(end)
            
            # Create safety grid
            safety_grid = self._create_safety_grid(
                unsafe_areas or [],
                police_stations or [],
                hospitals or []
            )
            
            # A* search
            path, avg_safety_score, distance, time = self._a_star_search(
                start_grid, end_grid, safety_grid
            )
            
            # If A* succeeds in finding a bypass route, convert path back to GPS coords
            if path and len(path) > 2:
                waypoints = []
                tuple_waypoints = []
                for point in path:
                    lat_lng = self._grid_to_lat_lng(point)
                    tuple_waypoints.append(lat_lng)
                    res = self.calculator.calculate_score(lat_lng[0], lat_lng[1], unsafe_areas or [])
                    waypoints.append({
                        "latitude": lat_lng[0],
                        "longitude": lat_lng[1],
                        "safety_score": res["safety_score"],
                        "risk_level": res["status"],
                        "color": res["color_code"]
                    })
                
                nearby_police = self._find_nearby_emergency_services(
                    tuple_waypoints, police_stations or [], 3
                )
                nearby_hospitals = self._find_nearby_emergency_services(
                    tuple_waypoints, hospitals or [], 3
                )
                
                return {
                    "waypoints": waypoints,
                    "safety_score": int(avg_safety_score),
                    "distance": round(distance, 2),
                    "estimated_time": int(round(time)),
                    "police_stations_nearby": nearby_police,
                    "hospitals_nearby": nearby_hospitals,
                    "warnings": self._generate_warnings(tuple_waypoints, unsafe_areas or [])
                }

            # 2. Try querying real roads via OSRM if A* is simple/failed
            osrm_coords = self._fetch_osrm_route(start, end)
            
            if osrm_coords:
                logger.info(f"OSRM path resolved with {len(osrm_coords)} nodes. Calculating segment safety...")
                waypoints = []
                total_safety_score = 0
                for lat, lng in osrm_coords:
                    res = self.calculator.calculate_score(lat, lng, unsafe_areas or [])
                    total_safety_score += res["safety_score"]
                    waypoints.append({
                        "latitude": lat,
                        "longitude": lng,
                        "safety_score": res["safety_score"],
                        "risk_level": res["status"],
                        "color": res["color_code"]
                    })
                avg_safety = total_safety_score / len(osrm_coords) if osrm_coords else 90
                
                # Calculate real route distance & duration
                distance_km = 0.0
                for i in range(len(osrm_coords) - 1):
                    distance_km += self._calculate_distance(
                        osrm_coords[i][0], osrm_coords[i][1],
                        osrm_coords[i+1][0], osrm_coords[i+1][1]
                    )
                time_mins = (distance_km / 5.0) * 60.0 # 5 km/h walking speed
                
                # Find nearby emergency services along the road path
                nearby_police = self._find_nearby_emergency_services(
                    osrm_coords, police_stations or [], 3
                )
                nearby_hospitals = self._find_nearby_emergency_services(
                    osrm_coords, hospitals or [], 3
                )
                
                return {
                    "waypoints": waypoints,
                    "safety_score": int(avg_safety),
                    "distance": round(distance_km, 2),
                    "estimated_time": int(round(time_mins)),
                    "police_stations_nearby": nearby_police,
                    "hospitals_nearby": nearby_hospitals,
                    "warnings": self._generate_warnings(osrm_coords, unsafe_areas or [])
                }

        except Exception as e:
            logger.error(f"Error in find_safe_route fallback: {str(e)}")
            fallback_res = self.calculator.calculate_score(start[0], start[1], unsafe_areas or [])
            return {
                "waypoints": [
                    {
                        "latitude": start[0],
                        "longitude": start[1],
                        "safety_score": fallback_res["safety_score"],
                        "risk_level": fallback_res["status"],
                        "color": fallback_res["color_code"]
                    },
                    {
                        "latitude": end[0],
                        "longitude": end[1],
                        "safety_score": fallback_res["safety_score"],
                        "risk_level": fallback_res["status"],
                        "color": fallback_res["color_code"]
                    }
                ],
                "safety_score": fallback_res["safety_score"],
                "distance": 1.0,
                "estimated_time": 15,
                "police_stations_nearby": [],
                "hospitals_nearby": [],
                "warnings": ["Route calculation failed, using direct path"]
            }

    def _lat_lng_to_grid(self, coord: Tuple[float, float]) -> Tuple[int, int]:
        """Convert latitude/longitude to grid coordinates"""
        lat, lng = coord
        x = int((lng - self.base_lng) / self.resolution)
        y = int((lat - self.base_lat) / self.resolution)
        # Keep inside bounds
        x = max(0, min(self.grid_size - 1, x))
        y = max(0, min(self.grid_size - 1, y))
        return (x, y)
    
    def _grid_to_lat_lng(self, grid: Tuple[int, int]) -> Tuple[float, float]:
        """Convert grid coordinates back to latitude/longitude"""
        x, y = grid
        lat = self.base_lat + (y * self.resolution)
        lng = self.base_lng + (x * self.resolution)
        return (lat, lng)
    
    def _create_safety_grid(self, unsafe_areas: List[Dict], 
                           police_stations: List[Dict], 
                           hospitals: List[Dict]) -> List[List[float]]:
        """Create a grid with safety scores (0-1, where 1 is safest)"""
        grid = [[0.5 for _ in range(self.grid_size)] for _ in range(self.grid_size)]
        
        # Reduce safety for unsafe areas
        for area in unsafe_areas:
            lat = area.get('latitude', area.get('lat', 0))
            lng = area.get('longitude', area.get('lng', 0))
            grid_pos = self._lat_lng_to_grid((lat, lng))
            x, y = grid_pos
            for i in range(max(0, x-5), min(self.grid_size, x+6)):
                for j in range(max(0, y-5), min(self.grid_size, y+6)):
                    distance = math.sqrt((i-x)**2 + (j-y)**2)
                    if distance <= 5:
                        penalty = 0.25 * (1 - distance/5)
                        grid[i][j] = max(0.05, grid[i][j] - penalty)
        
        # Increase safety near police stations
        for station in police_stations:
            lat = station.get('lat', 0)
            lng = station.get('lng', 0)
            grid_pos = self._lat_lng_to_grid((lat, lng))
            x, y = grid_pos
            for i in range(max(0, x-3), min(self.grid_size, x+4)):
                for j in range(max(0, y-3), min(self.grid_size, y+4)):
                    distance = math.sqrt((i-x)**2 + (j-y)**2)
                    if distance <= 3:
                        bonus = 0.12 * (1 - distance/3)
                        grid[i][j] = min(1.0, grid[i][j] + bonus)
        
        return grid
    
    def _a_star_search(self, start: Tuple[int, int], end: Tuple[int, int], 
                        grid: List[List[float]]) -> Tuple[List, float, float, float]:
        """A* pathfinding algorithm with safety scoring"""
        pq = [(0, 0, start)]
        came_from = {}
        g_score = {start: 0}
        f_score = {start: self._heuristic(start, end)}
        
        directions = [(0, 1), (1, 0), (0, -1), (-1, 0), 
                      (1, 1), (1, -1), (-1, 1), (-1, -1)]
        
        while pq:
            _, _, current = heapq.heappop(pq)
            
            if current == end:
                path = [current]
                while current in came_from:
                    current = came_from[current]
                    path.append(current)
                path.reverse()
                
                total_safety = sum(grid[x][y] for x, y in path) / len(path)
                distance = len(path) * 0.111  # Approximate distance in km
                time = distance / 5 * 60
                
                return path, total_safety * 100, distance, time
            
            for dx, dy in directions:
                nx, ny = current[0] + dx, current[1] + dy
                neighbor = (nx, ny)
                
                if 0 <= nx < self.grid_size and 0 <= ny < self.grid_size:
                    safety_penalty = ((1.0 - grid[nx][ny]) ** 2) * 80.0
                    move_cost = math.sqrt(dx*dx + dy*dy) + safety_penalty
                    tentative_g = g_score[current] + move_cost
                    
                    if neighbor not in g_score or tentative_g < g_score[neighbor]:
                        came_from[neighbor] = current
                        g_score[neighbor] = tentative_g
                        f_score[neighbor] = tentative_g + self._heuristic(neighbor, end) * 1.1
                        heapq.heappush(pq, (f_score[neighbor], tentative_g, neighbor))
        
        return [start, end], 50, 1.0, 15
    
    def _heuristic(self, a: Tuple[int, int], b: Tuple[int, int]) -> float:
        return math.sqrt((a[0] - b[0])**2 + (a[1] - b[1])**2)
    
    def _find_nearby_emergency_services(self, path: List[Tuple], services: List[Dict], 
                                       count: int) -> List[Dict]:
        if not path:
            return []
        
        mid_index = len(path) // 2
        path_center = path[mid_index] if mid_index < len(path) else path[0]
        
        distances = []
        for service in services:
            service_pos = (service.get('lat', 0), service.get('lng', 0))
            distance = geodesic(path_center, service_pos).km
            distances.append((distance, service))
        
        distances.sort(key=lambda x: x[0])
        return [s for _, s in distances[:count]]
    
    def _generate_warnings(self, waypoints: List[Tuple], unsafe_areas: List[Dict]) -> List[str]:
        warnings = []
        for point in waypoints:
            for area in unsafe_areas:
                area_pos = (area.get('latitude', area.get('lat', 0)), 
                           area.get('longitude', area.get('lng', 0)))
                distance = geodesic(point, area_pos).km
                if distance < 0.35:
                    warnings.append("⚠️ Path crosses inside a high-crime incident warning cluster")
                    break
        return list(set(warnings))[:3]