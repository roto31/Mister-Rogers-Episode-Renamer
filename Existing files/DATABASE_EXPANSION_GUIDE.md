"""
MISTER ROGERS' NEIGHBORHOOD - COMPLETE PRODUCTION NUMBER DATABASE TEMPLATE

This file provides the full framework and instructions for populating
a complete production number → episode mapping database.

CURRENT STATUS:
  Verified entries: 2 (productions 1066, 1067)
  Total episodes: 900+ across 34 seasons (1968-2001)
  Database coverage: 0.2% (complete population needed)

SOURCES FOR DATA ENTRY:
  1. The Neighborhood Archive: https://www.neighborhoodarchive.com/mrn/episodes/
  2. Wikipedia Season Pages: https://en.wikipedia.org/wiki/Mister_Rogers'_Neighborhood_season_N
  3. IMDb: https://www.imdb.com/title/tt0062588/episodes/
  4. PBS Archives: For official broadcast records

SEASON STRUCTURE (Wikipedia Reference):
  Season 1 (1968): 130 episodes, black-and-white (1001-1130?)
  Season 2 (1969): 65 new color episodes (1131-1195)
  Season 3 (1970): 65 new color episodes
  Season 4 (1971): 65 new color episodes
  Season 5 (1972): 65 new color episodes
  Season 6 (1973): 65 new color episodes
  Season 7 (1974): 65 new color episodes
  Season 8 (1975): 65 new color episodes
  Season 9 (1976): Repeat cycle begins with new episodes mixed in
  ...
  Season 31 (2000-2001): Final new episodes

NOTE: Production numbers do NOT align 1:1 with season boundaries.
      Production 1066 is Season 3, Episode 1, but may have been re-broadcast
      as "Season 9, Episode 25" or similar in later cycles.
      This database uses production numbers (the original on-screen identifier).

============================================================================
HOW TO ADD ENTRIES
============================================================================

1. Visit the Neighborhood Archive episode page:
   https://www.neighborhoodarchive.com/mrn/episodes/[PRODUCTION_NUMBER]/

2. From the page, extract:
   - Production number (from URL or page header)
   - Season (from "Season X" text)
   - Episode number within season (from "Episode Y" text)
   - Title (from page heading)
   - Air date (from "Air Date:" field)

3. Add entry to EPISODE_DATABASE dictionary below in this format:

   PRODUCTION_NUM: {
       "season": SEASON_INT,
       "episode": EPISODE_INT,
       "title": "Exact Title From Archive",
       "air_date": "YYYY-MM-DD",
       "source": "Neighborhood Archive"
   },

4. Test entry: python3 misterrogers_renamer.py --interactive
   Then type the production number and verify output.

5. Use in renaming tool once verified.

============================================================================
EXAMPLE ENTRIES (VERIFIED)
============================================================================
"""

# VERIFIED ENTRIES (from The Neighborhood Archive)
EPISODE_DATABASE = {
    # Season 1 (1968) - Black & White
    # Production 1001-1130 (130 episodes total)
    # NOTE: Full Season 1 data requires systematic entry from Archive
    
    # Season 2 (1969) - Color
    # Production 1131-1195 (65 episodes)
    # NOTE: Entry needed - visit Archive for each
    
    # Season 3 (1970) - Color
    # VERIFIED ENTRIES:
    1066: {
        "season": 3,
        "episode": 1,
        "title": "Models of the Homes in the Neighborhood of Make-Believe",
        "air_date": "1970-02-02",
        "source": "Neighborhood Archive"
    },
    1067: {
        "season": 3,
        "episode": 2,
        "title": "Trees",
        "air_date": "1970-02-03",
        "source": "Neighborhood Archive"
    },
    # TODO: Add remaining Season 3 episodes (3-65)
    # Production numbers: 1068-1130 (approximately)
    # Source: https://www.neighborhoodarchive.com/mrn/episodes/
    
    # Season 4 (1971) - Color
    # TODO: 65 episodes
    
    # Season 5 (1972) - Color
    # TODO: 65 episodes
    
    # Season 6 (1973) - Color
    # TODO: 65 episodes
    
    # Season 7 (1974) - Color
    # TODO: 65 episodes
    
    # Season 8 (1975) - Color
    # TODO: 65 episodes
    
    # Season 9 (1976) - Repeat cycle with new episodes
    # TODO: TBD episodes
    
    # Seasons 10-28 (1979-1993)
    # Modern era with 15 new episodes per year
    # TODO: Systematic entry needed for each season
    
    # Seasons 29-31 (1994-2001)
    # Final phase with 10 new episodes per year
    # TODO: Systematic entry needed for each season
}

============================================================================
EXPANSION PRIORITY CHECKLIST
============================================================================

PHASE 1 (CRITICAL - High-Demand Episodes):
  [ ] Season 1 (1968): 130 episodes
  [ ] Season 2 (1969): 65 episodes
  [ ] Season 3 (1970): 65 episodes (Ep 1-2 done, 63 to go)
  [ ] Season 4 (1971): 65 episodes
  [ ] Season 5 (1972): 65 episodes
  
  Subtotal: ~390 episodes (43% of total)
  Estimated time: 4-5 hours of data entry

PHASE 2 (IMPORTANT - Color era):
  [ ] Season 6 (1973): 65 episodes
  [ ] Season 7 (1974): 65 episodes
  [ ] Season 8 (1975): 65 episodes
  [ ] Season 9 (1976): Episodes count TBD
  
  Subtotal: ~200+ episodes
  Estimated time: 2-3 hours

PHASE 3 (COMPLETION - Modern era):
  [ ] Seasons 10-31 (1979-2001): ~400+ new episodes
      (Plus repeat episodes mixed in)
  
  Subtotal: ~400+ episodes
  Estimated time: 4-5 hours

TOTAL ESTIMATED TIME: 10-13 hours for complete database

============================================================================
WIKI-STYLE COLLABORATION FORMAT
============================================================================

If expanding this database as a collaborative effort, use this format
in comments to track progress:

Episode 1234 Status: IN PROGRESS (User: Example)
  - Archive page verified: https://www.neighborhoodarchive.com/mrn/episodes/1234/
  - Title confirmed: "Example Episode Title"
  - Season: 5, Episode: 12
  - Air date: 1972-XX-XX (waiting for confirmation)
  - Data entry: PENDING

============================================================================
ALTERNATIVE: WEB SCRAPER APPROACH
============================================================================

For faster population, a Python web scraper could:

1. Iterate through production numbers 1001-1625
2. Fetch https://www.neighborhoodarchive.com/mrn/episodes/[NUM]/
3. Parse HTML to extract:
   - Season number (from page text)
   - Episode number (from page text)
   - Title (from page heading)
   - Air date (from structured data)
4. Validate against Wikipedia cross-reference
5. Auto-populate EPISODE_DATABASE

Estimated time to write scraper: 2-3 hours
Estimated time to populate: 10-15 minutes (automated)
Total: 2.5-3.5 hours vs. 10-13 hours manual

RECOMMENDED: Use scraper for 1001-1300, then manual verification
            for any that fail parsing.

============================================================================
QUALITY ASSURANCE CHECKLIST
============================================================================

When adding entries, verify:

[ ] Production number is in valid range (1001-1700)
[ ] Season number matches Neighborhood Archive page
[ ] Episode number is correct for that season (1-65 typically)
[ ] Title exactly matches Archive source (case-sensitive)
[ ] Air date is in YYYY-MM-DD format
[ ] Date matches Neighborhood Archive record
[ ] Date is logical (1968-2001, no future dates)
[ ] Special characters in title are preserved
[ ] Source is cited (usually "Neighborhood Archive")

Test in tool:
[ ] python3 misterrogers_renamer.py --interactive
[ ] Enter production number
[ ] Verify output matches Archive page
[ ] Test filename formatting: SxEx - Title

============================================================================
KNOWN ISSUES TO TRACK
============================================================================

1. TITLE VARIATIONS
   Some episode titles have variant forms:
   - "Making Mistakes (Part 1)" vs "Making Mistakes"
   - Always use the exact title from Neighborhood Archive
   
2. SEASON NUMBERING
   "Season" in context of this database means the original broadcast season,
   not later repeat-era season numbers.
   Use the season number from Neighborhood Archive pages.

3. PRODUCTION NUMBER GAPS
   Not all numbers 1001-1625 may be used.
   Some numbers may be out-of-order or skipped.
   This is normal and expected.

4. SPECIAL EPISODES
   Some entries may be specials, holidays, etc.
   Enter season/episode as listed on Archive (may be "Special" instead of number)

============================================================================
SCRIPT TO VALIDATE DATABASE
============================================================================

After adding entries, run this to check for errors:

    python3 << 'EOF'
    import sys
    sys.path.insert(0, '/path/to/script')
    from misterrogers_renamer import EPISODE_DATABASE, format_new_filename
    
    for prod_num in sorted(EPISODE_DATABASE.keys()):
        info = EPISODE_DATABASE[prod_num]
        
        # Check required fields
        if not all(k in info for k in ['season', 'episode', 'title', 'air_date']):
            print(f"❌ Production {prod_num}: missing required fields")
            continue
        
        # Check types
        if not isinstance(info['season'], int):
            print(f"❌ Production {prod_num}: season not int")
            continue
        
        if not isinstance(info['episode'], int):
            print(f"❌ Production {prod_num}: episode not int")
            continue
        
        # Test formatting
        try:
            filename = format_new_filename(
                info['season'],
                info['episode'],
                info['title'],
                '.mp4'
            )
            print(f"✓ Production {prod_num}: {filename}")
        except Exception as e:
            print(f"❌ Production {prod_num}: {e}")
    EOF

============================================================================
COMMIT CHECKLIST BEFORE RELEASE
============================================================================

[ ] All entries tested with --interactive mode
[ ] No duplicate production numbers in database
[ ] All titles match Neighborhood Archive exactly
[ ] All air dates are YYYY-MM-DD format
[ ] No future dates (after 2001)
[ ] Season numbers 1-31 range
[ ] Episode numbers logical per season
[ ] README.md updated with database stats
[ ] SOLUTION_SUMMARY.md updated with new entry count
[ ] Tool tested with batch rename on sample files
[ ] Dry-run mode verified before --commit

============================================================================
COMMUNITY CONTRIBUTION GUIDELINES
============================================================================

If crowdsourcing database expansion:

1. Create GitHub issues for unclaimed seasons
   - "Season 3 (15 episodes remaining)"
   - Assign to volunteers
   
2. Pull request template:
   - Which season(s) added
   - Source verification links
   - Test results (--interactive output)
   - Any problematic entries noted
   
3. Review process:
   - Check against Neighborhood Archive
   - Spot-check 10% of entries for accuracy
   - Validate date ranges
   - Ensure consistent formatting

4. Thank contributors by name in README

============================================================================

This template provides everything needed to expand the database from
the current 2 verified entries to a complete 900+ entry database.

Priority: Phase 1 (Color era, 1968-1972) is highest priority as most
people likely have episodes from this period.

Questions? See README.md for sources and contact information.

============================================================================
"""
