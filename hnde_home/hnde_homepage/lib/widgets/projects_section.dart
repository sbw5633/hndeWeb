import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/project.dart';

class ProjectsSection extends StatelessWidget {
  final List<Project> projects;

  const ProjectsSection({
    super.key,
    required this.projects,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 48,
        vertical: 80,
      ),
      color: Colors.grey[50],
      child: Column(
        children: [
          Text(
            '프로젝트',
            style: GoogleFonts.notoSans(
              fontSize: isMobile ? 32 : 48,
              fontWeight: FontWeight.bold,
              color: Colors.blue[900],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 4,
            color: Colors.blue[700],
          ),
          const SizedBox(height: 60),
          ...projects.map(
            (project) => Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: _ProjectCard(project: project),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;

  const _ProjectCard({
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 64,
                      color: Colors.blue[300],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: _ProjectContent(project: project),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 300,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.image,
                      size: 64,
                      color: Colors.blue[300],
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _ProjectContent(project: project),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProjectContent extends StatelessWidget {
  final Project project;

  const _ProjectContent({
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue[700],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                project.category,
                style: GoogleFonts.notoSans(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              project.location,
              style: GoogleFonts.notoSans(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          project.title,
          style: GoogleFonts.notoSans(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          project.description,
          style: GoogleFonts.notoSans(
            fontSize: 16,
            color: Colors.grey[700],
            height: 1.6,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: project.tags
              .map(
                (tag) => Chip(
                  label: Text(
                    tag,
                    style: GoogleFonts.notoSans(fontSize: 12),
                  ),
                  backgroundColor: Colors.grey[100],
                  padding: EdgeInsets.zero,
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 16),
        Text(
          '완료일: ${project.completedDate.year}.${project.completedDate.month}.${project.completedDate.day}',
          style: GoogleFonts.notoSans(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
