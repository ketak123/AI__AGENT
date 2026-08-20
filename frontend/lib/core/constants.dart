import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'Autonomous Business Suite';
  
  // Environment-provided or default API URL
  static const String defaultApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8001/api',
  );

  static const List<Map<String, dynamic>> agentRoles = [
    {
      'id': 'ai_manager',
      'name': 'AI General Manager',
      'icon': Icons.smart_toy_outlined,
      'color': Color(0xFF6366F1),
      'desc': 'Omniscient executive coordinating all operations',
      'description': 'Omniscient executive coordinating all operations',
    },
    {
      'id': 'strategy',
      'name': 'Chief Strategy Officer',
      'icon': Icons.insights_outlined,
      'color': Color(0xFF3B82F6),
      'desc': 'Market positioning, SWOT, business models',
      'description': 'Market positioning, SWOT, business models',
    },
    {
      'id': 'product',
      'name': 'VP of Product & Tech',
      'icon': Icons.code_rounded,
      'color': Color(0xFF06B6D4),
      'desc': 'MVP scope, roadmaps, technical architecture',
      'description': 'MVP scope, roadmaps, technical architecture',
    },
    {
      'id': 'marketing',
      'name': 'Head of Growth & Mktg',
      'icon': Icons.campaign_outlined,
      'color': Color(0xFFEC4899),
      'desc': 'Campaigns, ad copy, lead funnels',
      'description': 'Campaigns, ad copy, lead funnels',
    },
    {
      'id': 'finance',
      'name': 'Chief Financial Officer',
      'icon': Icons.account_balance_outlined,
      'color': Color(0xFF10B981),
      'desc': 'Unit economics, pricing, margin forecast',
      'description': 'Unit economics, pricing, margin forecast',
    },
    {
      'id': 'social_media',
      'name': 'Social Media Manager',
      'icon': Icons.share_outlined,
      'color': Color(0xFFF59E0B),
      'desc': 'Omnichannel post generator & dispatcher',
      'description': 'Omnichannel post generator & dispatcher',
    },
  ];
}
