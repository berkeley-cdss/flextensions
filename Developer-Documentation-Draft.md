# Draft: Developer Documentation Notes / Feedback / Potential Edits

## General Notes & Feedback for Developer Setup Documentation
- Should add images to supplement detailed step-by-step walkthrough
- Need to fix some confusing spelling / grammatical errors
- Maybe add a(n) FAQ section?
- Consider including error fixes for issues that developers might run into during the setup process

## Specific Developer Setup Documentation Potential Edits
### ENVIRONMENT VARIABLES SECTION:
- Line "Copy .env.sample to .env" should be changed to "Copy **.env.example** to .env" (and maybe we should include the specific command to do so?)
- Maybe provide a link to the Sandbox Admin account login page
- Directions for creating a new API key should be much more specific (which scopes should be selected? how should the user name the key? which "Redirect URI" field should be filled out? what about the other fields? what are they / what do they mean and should the user pay them any mind?) and should definitely include images for extra clarification regarding what to click, what fields to type in, and transitioning from page to page (very unclear at the moment)
- The page transition from point iv. to point v. needs to be more clear
- Need clearer instructions regarding setting up the ENV variables in the .env file (any specifications / preferences on organization and exactness should be clarified)
- Instead of "In the root directory of Flextensions app," maybe just say "In the `flextensions` directory" since that is the root directory (from my understanding)

### RAILS DATABASE SECTION:
- `rails db:setup` command doesn't work (at least not for me), so alternative option of `bundle exec rails db:setup` should be specified
  - And in this case, `bundle install` command should also be recommended prior to bundle exec
- I ran into a lot of errors in this section, regarding versioning with both ruby and bundle, as well as some file path errors(?) (specifically when trying to run both `bundle install` and `bundle exec rails db:setup`.
  - I had to receive help from AI to fix these so that I could run the server - took hours, so **my recommendation is to anticipate other users having these same issues and incorporate a "Common Errors" section, or simply addressing the potential errors within this subsection.** I can provide some documentation of my errors and the overall solutions that worked for me if needed.
- I also had to make sure that PostgreSQL was running before I could set up the DB with `bundle exec rails db:setup`. This was unclear and should be specified.

### HYPERSHIELD SECTION:
- The `rake hypershield:refresh:dry_run` command didn't work for me. The rake was aborted and I wasn't sure what to do so I left it at that. An alternative command and more details should be provided here.

### HEROKU SECTION:
- This section is very unclear as I'm unsure if I'm supposed to have a Heroku account dedicated to flextensions and/or if there's a specific class account that I should have specifically for flextensions dev
- I didn't complete the section because it's unclear where exactly to begin
- The following should be clarified for other developers:
  - Is there a specific Heroku group or class account that we need to join?
  - Is this Heroku setup supposed to be completed within a personal Heroku account? If so, what is the setup process from the very beginning? (should include images to account for users who are unfamiliar with Heroku)
  - The instructions simply begin with setting the ENV variables within Heroku. How did we get here?
 
### NOTES SECTION:
- More details regarding the recommendation the order in which users should develop might be helpful
  - Including but not limited to: Why should they develop in that order? What do the risks actually entail? How should they actually begin developing in each environment? What does it mean to "develop in these environments" (i.e. how do they switch from environment to environment, and how can they check which environment they are currently developing in?)?
