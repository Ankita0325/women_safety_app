import math
import heapq
from typing import List, Tuple, Dict, Optional
from geopy.distance import geodesic
import logging

logger = logging.getLogger(__name__)

class RouteService:
    """Route service with A* algorithm for safe pathfinding"""
    
    def __init__(self):
        self.grid_size = 100
        self.resolution = 0.001  # degrees per grid cell
        self.base_lat = 19.0
        self.base_lng = 72.8
        self.unsafe_areas = []
        self.police_stations = []
        self.hospitals = []
    
    def find_safe_route(self, start: Tuple[float, float], end: Tuple[float, float], 
                       unsafe_areas: List[Dict] = None, police_stations: List[Dict] = None,
                       hospitals: List[Dict] = None) -> Dict:
        """
        Find the safest route using A* algorithm with safety scoring
        
        Args:
            start: (lat, lng) tuple
            end: (lat, lng) tuple
            unsafe_areas: List of dicts with lat, lng keys
            police_stations: List of dicts with lat, lng keys
            hospitals: List of dicts with lat, lng keys
            
        Returns:
            Dict with route information
        """
        try:
            # Convert to grid coordinates
            start_grid = self._lat_lng_to_grid(start)
            end_grid = self._lat_lng_to_grid(end)
            
            # Create safety grid
            safety_grid = self._create_safety_grid(
                unsafe_areas or [],
                police_stations or [],
                hospitals or []
            )
            
            # A* algorithm
            path, safety_score, distance, time = self._a_star_search(
                start_grid, end_grid, safety_grid
            )
            
            # Convert path back to coordinates
            waypoints = [self._grid_to_lat_lng(point) for point in path]
            
            # Find nearby emergency services
            nearby_police = self._find_nearby_emergency_services(
                waypoints, police_stations or [], 3
            )
            nearby_hospitals = self._find_nearby_emergency_services(
                waypoints, hospitals or [], 3
            )
            
            return {
                "waypoints": waypoints,
                "safety_score": safety_score,
                "distance": distance,
                "estimated_time": time,
                "police_stations_nearby": nearby_police,
                "hospitals_nearby": nearby_hospitals,
                "warnings": self._generate_warnings(waypoints, unsafe_areas or [])
            }
        except Exception as e:
            logger.error(f"Error in find_safe_route: {str(e)}")
            return {
                "waypoints": [start, end],
                "safety_score": 50,
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
        # Initialize with neutral safety score (0.5)
        grid = [[0.5 for _ in range(self.grid_size)] for _ in range(self.grid_size)]
        
        # Reduce safety for unsafe areas
        for area in unsafe_areas:
            lat = area.get('latitude', area.get('lat', 0))
            lng = area.get('longitude', area.get('lng', 0))
            grid_pos = self._lat_lng_to_grid((lat, lng))
            x, y = grid_pos
            if 0 <= x < self.grid_size and 0 <= y < self.grid_size:
                for i in range(max(0, x-5), min(self.grid_size, x+6)):
                    for j in range(max(0, y-5), min(self.grid_size, y+6)):
                        distance = math.sqrt((i-x)**2 + (j-y)**2)
                        if distance <= 5:
                            penalty = 0.15 * (1 - distance/5)
                            grid[i][j] = max(0.1, grid[i][j] - penalty)
        
        # Increase safety near police stations
        for station in police_stations:
            lat = station.get('lat', 0)
            lng = station.get('lng', 0)
            grid_pos = self._lat_lng_to_grid((lat, lng))
            x, y = grid_pos
            if 0 <= x < self.grid_size and 0 <= y < self.grid_size:
                for i in range(max(0, x-3), min(self.grid_size, x+4)):
                    for j in range(max(0, y-3), min(self.grid_size, y+4)):
                        distance = math.sqrt((i-x)**2 + (j-y)**2)
                        if distance <= 3:
                            bonus = 0.12 * (1 - distance/3)
                            grid[i][j] = min(1, grid[i][j] + bonus)
        
        # Increase safety near hospitals
        for hospital in hospitals:
            lat = hospital.get('lat', 0)
            lng = hospital.get('lng', 0)
            grid_pos = self._lat_lng_to_grid((lat, lng))
            x, y = grid_pos
            if 0 <= x < self.grid_size and 0 <= y < self.grid_size:
                for i in range(max(0, x-2), min(self.grid_size, x+3)):
                    for j in range(max(0, y-2), min(self.grid_size, y+3)):
                        distance = math.sqrt((i-x)**2 + (j-y)**2)
                        if distance <= 2:
                            bonus = 0.08 * (1 - distance/2)
                            grid[i][j] = min(1, grid[i][j] + bonus)
        
        return grid
    
    def _a_star_search(self, start: Tuple[int, int], end: Tuple[int, int], 
                       grid: List[List[float]]) -> Tuple[List, float, float, float]:
        """A* pathfinding algorithm with safety scoring"""
        # Priority queue: (f_score, g_score, position)
        pq = [(0, 0, start)]
        came_from = {}
        g_score = {start: 0}
        f_score = {start: self._heuristic(start, end)}
        
        # 8-direction movement
        directions = [(0, 1), (1, 0), (0, -1), (-1, 0), 
                      (1, 1), (1, -1), (-1, 1), (-1, -1)]
        
        while pq:
            _, _, current = heapq.heappop(pq)
            
            if current == end:
                # Reconstruct path
                path = [current]
                while current in came_from:
                    current = came_from[current]
                    path.append(current)
                path.reverse()
                
                # Calculate metrics
                total_safety = sum(grid[x][y] for x, y in path) / len(path)
                distance = len(path) * 0.111  # Approximate distance in km
                time = distance / 5 * 60  # 5 km/h walking speed, convert to minutes
                
                return path, total_safety * 100, distance, time
            
            for dx, dy in directions:
                nx, ny = current[0] + dx, current[1] + dy
                neighbor = (nx, ny)
                
                if 0 <= nx < self.grid_size and 0 <= ny < self.grid_size:
                    # Cost = distance + (1 - safety) * weight
                    safety_penalty = (1 - grid[nx][ny]) * 3
                    move_cost = math.sqrt(dx*dx + dy*dy) + safety_penalty
                    
                    tentative_g = g_score[current] + move_cost
                    
                    if neighbor not in g_score or tentative_g < g_score[neighbor]:
                        came_from[neighbor] = current
                        g_score[neighbor] = tentative_g
                        f_score[neighbor] = tentative_g + self._heuristic(neighbor, end) * 1.1
                        heapq.heappush(pq, (f_score[neighbor], tentative_g, neighbor))
        
        # No path found, return direct path
        return [start, end], 50, 1.0, 15
    
    def _heuristic(self, a: Tuple[int, int], b: Tuple[int, int]) -> float:
        """Euclidean distance heuristic"""
        return math.sqrt((a[0] - b[0])**2 + (a[1] - b[1])**2)
    
    def _find_nearby_emergency_services(self, path: List[Tuple], services: List[Dict], 
                                       count: int) -> List[Dict]:
        """Find nearby emergency services along the path"""
        if not path:
            return []
        
        # Use the midpoint of the path
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
        """Generate warnings along the route"""
        warnings = []
        
        for point in waypoints:
            for area in unsafe_areas:
                area_pos = (area.get('latitude', area.get('lat', 0)), 
                           area.get('longitude', area.get('lng', 0)))
                distance = geodesic(point, area_pos).km
                
                if distance < 0.5:  # Within 500m
                    warnings.append("⚠️ Near an unsafe area")
                    break
                elif distance < 1.0:  # Within 1km
                    warnings.append("⚠️ Approaching an area with recent incidents")
                    break
        
        return list(set(warnings))[:3]  # Return unique warnings, max 3