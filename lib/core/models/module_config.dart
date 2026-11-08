import 'package:flutter/material.dart';

class FieldConfig {
  const FieldConfig(this.key, this.label, {this.multiline = false, this.numeric = false, this.required = false});
  final String key, label;
  final bool multiline, numeric, required;
}

class ModuleConfig {
  const ModuleConfig({required this.table, required this.title, required this.icon, required this.fields,
    this.dateKey, this.subtitleKey, this.category});
  final String table, title;
  final IconData icon;
  final List<FieldConfig> fields;
  final String? dateKey, subtitleKey, category;
}

final modules = <ModuleConfig>[
  ModuleConfig(table: 'memories', title: 'Memories', icon: Icons.photo_album_outlined, dateKey: 'memory_date',
    subtitleKey: 'description', fields: [FieldConfig('title','Memory title',required:true), FieldConfig('description','What happened?',multiline:true), FieldConfig('memory_date','Date (YYYY-MM-DD)',required:true), FieldConfig('category','Category')]),
  ModuleConfig(table: 'love_notes', title: 'Love Notes', icon: Icons.mail_outline, subtitleKey: 'body',
    fields: [FieldConfig('title','Title',required:true), FieldConfig('body','Your letter or message',multiline:true,required:true), FieldConfig('note_type','Type')]),
  ModuleConfig(table: 'important_dates', title: 'Important Dates', icon: Icons.event_outlined, dateKey: 'event_date',
    subtitleKey: 'notes', fields: [FieldConfig('title','Event title',required:true), FieldConfig('event_date','Date (YYYY-MM-DD)',required:true), FieldConfig('notes','Notes',multiline:true), FieldConfig('recurrence','Recurrence (None/Yearly)')]),
  ModuleConfig(table: 'date_plans', title: 'Date Planner', icon: Icons.restaurant_outlined, dateKey: 'scheduled_at',
    subtitleKey: 'location', fields: [FieldConfig('title','Date idea',required:true), FieldConfig('description','Description',multiline:true), FieldConfig('scheduled_at','Schedule (YYYY-MM-DD)',required:true), FieldConfig('location','Location'), FieldConfig('budget','Budget',numeric:true), FieldConfig('category','Category'), FieldConfig('status','Status (Planned/Completed/Cancelled)')]),
  ModuleConfig(table: 'bucket_list', title: 'Our Bucket List', icon: Icons.checklist, subtitleKey: 'notes',
    fields: [FieldConfig('title','Something to do together',required:true), FieldConfig('notes','Notes',multiline:true), FieldConfig('category','Category')]),
  ModuleConfig(table: 'mood_entries', title: 'Mood Check-ins', icon: Icons.mood_outlined, dateKey: 'entry_date',
    subtitleKey: 'reflection', fields: [FieldConfig('mood','Mood (Happy/Okay/Sad/Anxious)',required:true), FieldConfig('happiness','Happiness rating (1-5)',numeric:true), FieldConfig('reflection','Reflection',multiline:true), FieldConfig('gratitude','Something grateful for',multiline:true), FieldConfig('entry_date','Date (YYYY-MM-DD)',required:true)]),
  ModuleConfig(table: 'expenses', title: 'Shared Expenses', icon: Icons.payments_outlined, dateKey: 'expense_date',
    subtitleKey: 'paid_by', fields: [FieldConfig('title','Expense name',required:true), FieldConfig('amount','Amount (₱)',numeric:true,required:true), FieldConfig('category','Category'), FieldConfig('paid_by','Paid by',required:true), FieldConfig('description','Description',multiline:true), FieldConfig('expense_date','Date (YYYY-MM-DD)',required:true)]),
  ModuleConfig(table: 'gift_wishlist', title: 'Gift Wishlist', icon: Icons.card_giftcard_outlined,
    fields: [FieldConfig('title','Gift idea',required:true), FieldConfig('description','Description',multiline:true), FieldConfig('estimated_price','Estimated price',numeric:true), FieldConfig('occasion','Occasion')]),
  ModuleConfig(table: 'relationship_goals', title: 'Relationship Goals', icon: Icons.flag_outlined,
    fields: [FieldConfig('title','Goal',required:true), FieldConfig('description','Description',multiline:true), FieldConfig('target_date','Target date (YYYY-MM-DD)'), FieldConfig('progress','Progress (0-100)',numeric:true), FieldConfig('status','Status')]),
  ModuleConfig(table: 'couple_challenges', title: 'Couple Questions & Challenges', icon: Icons.quiz_outlined,
    fields: [FieldConfig('prompt','Question or challenge',multiline:true,required:true), FieldConfig('category','Category')]),
];
